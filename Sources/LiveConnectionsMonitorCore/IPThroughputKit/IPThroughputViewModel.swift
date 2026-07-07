import AppKit
import Foundation

@MainActor
public final class IPThroughputViewModel: ObservableObject {
    @Published public private(set) var selectedIP: String?
    @Published public private(set) var pinnedIPs: Set<String> = []
    @Published public private(set) var series = IPThroughputSeries.empty()
    @Published public var isPaused = false
    @Published public var samplingIntervalMs: Int
    @Published public var timeWindow: IPThroughputTimeWindow
    @Published public var customTimeWindowSeconds: TimeInterval
    @Published public var maxSamplesPerIP: Int
    @Published public var showUploadLine: Bool
    @Published public var showDownloadLine: Bool
    @Published public var showTotalLine: Bool
    @Published public var keepHistoryAfterDeselection: Bool
    @Published public var enableCSVExport: Bool

    private let service = IPThroughputService()
    private var histories: [String: [ThroughputSample]] = [:]
    private var connectionsProvider: () -> [NetworkConnection]
    private var samplingTask: Task<Void, Never>?

    public init(connectionsProvider: @escaping () -> [NetworkConnection]) {
        self.connectionsProvider = connectionsProvider
        samplingIntervalMs = UserDefaults.standard.object(forKey: "ipThroughput.defaultSamplingIntervalMs") as? Int ?? 1_000
        timeWindow = IPThroughputTimeWindow(rawValue: UserDefaults.standard.string(forKey: "ipThroughput.defaultTimeWindow") ?? "") ?? .minute1
        customTimeWindowSeconds = UserDefaults.standard.object(forKey: "ipThroughput.customTimeWindowSeconds") as? Double ?? 300
        maxSamplesPerIP = UserDefaults.standard.object(forKey: "ipThroughput.maximumSamplesPerIP") as? Int ?? 2_000
        showUploadLine = UserDefaults.standard.object(forKey: "ipThroughput.showUploadLine") as? Bool ?? true
        showDownloadLine = UserDefaults.standard.object(forKey: "ipThroughput.showDownloadLine") as? Bool ?? true
        showTotalLine = UserDefaults.standard.object(forKey: "ipThroughput.showTotalLine") as? Bool ?? true
        keepHistoryAfterDeselection = UserDefaults.standard.bool(forKey: "ipThroughput.keepHistoryAfterDeselection")
        enableCSVExport = UserDefaults.standard.object(forKey: "ipThroughput.enableCSVExport") as? Bool ?? true
        Task { histories = (try? await service.loadPersisted()) ?? [:] }
    }

    deinit {
        samplingTask?.cancel()
    }

    public func select(ip: String?) {
        selectedIP = ip
        if let ip {
            rebuildSeries(for: ip)
            start()
        } else if !keepHistoryAfterDeselection {
            series = .empty()
        }
    }

    public func pin(ip: String) {
        pinnedIPs.insert(ip)
        select(ip: ip)
    }

    public func clear(ip: String) {
        histories[ip] = []
        if selectedIP == ip { rebuildSeries(for: ip) }
    }

    public func exportCSV(ip: String? = nil) {
        guard enableCSVExport else { return }
        let target = ip ?? selectedIP
        guard let target else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "throughput-\(target).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ThroughputCSVExporter.csv(samples: histories[target] ?? []).write(to: url, atomically: true, encoding: .utf8)
    }

    public func updateSettingsFromDefaults() {
        samplingIntervalMs = min(60_000, max(250, UserDefaults.standard.object(forKey: "ipThroughput.defaultSamplingIntervalMs") as? Int ?? samplingIntervalMs))
        timeWindow = IPThroughputTimeWindow(rawValue: UserDefaults.standard.string(forKey: "ipThroughput.defaultTimeWindow") ?? "") ?? timeWindow
        showUploadLine = UserDefaults.standard.object(forKey: "ipThroughput.showUploadLine") as? Bool ?? showUploadLine
        showDownloadLine = UserDefaults.standard.object(forKey: "ipThroughput.showDownloadLine") as? Bool ?? showDownloadLine
        showTotalLine = UserDefaults.standard.object(forKey: "ipThroughput.showTotalLine") as? Bool ?? showTotalLine
        keepHistoryAfterDeselection = UserDefaults.standard.bool(forKey: "ipThroughput.keepHistoryAfterDeselection")
        maxSamplesPerIP = max(100, UserDefaults.standard.object(forKey: "ipThroughput.maximumSamplesPerIP") as? Int ?? maxSamplesPerIP)
        enableCSVExport = UserDefaults.standard.object(forKey: "ipThroughput.enableCSVExport") as? Bool ?? enableCSVExport
        restart()
    }

    public func pauseResume() {
        isPaused.toggle()
    }

    private func start() {
        guard samplingTask == nil else { return }
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                let ms = self?.samplingIntervalMs ?? 1_000
                try? await Task.sleep(for: .milliseconds(ms))
            }
        }
    }

    private func restart() {
        samplingTask?.cancel()
        samplingTask = nil
        if selectedIP != nil || !pinnedIPs.isEmpty { start() }
    }

    private func tick() async {
        guard !isPaused else { return }
        let targets = Set([selectedIP].compactMap { $0 }).union(pinnedIPs)
        guard !targets.isEmpty else { return }
        let connections = connectionsProvider()
        for ip in targets {
            let sample = await service.sample(ip: ip, connections: connections)
            append(sample)
        }
        if keepHistoryAfterDeselection {
            try? await service.persist(histories)
        }
    }

    private func append(_ sample: ThroughputSample) {
        var values = histories[sample.ipAddress] ?? []
        values.append(sample)
        if values.count > maxSamplesPerIP {
            values.removeFirst(values.count - maxSamplesPerIP)
        }
        histories[sample.ipAddress] = values
        if selectedIP == sample.ipAddress {
            rebuildSeries(for: sample.ipAddress)
        }
    }

    private func rebuildSeries(for ip: String) {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        let samples = (histories[ip] ?? []).filter { $0.timestamp >= cutoff }
        let current = samples.last
        let avgIn = samples.isEmpty ? 0 : samples.map(\.bitsPerSecondIn).reduce(0, +) / Double(samples.count)
        let avgOut = samples.isEmpty ? 0 : samples.map(\.bitsPerSecondOut).reduce(0, +) / Double(samples.count)
        let avgTotal = samples.isEmpty ? 0 : samples.map(\.bitsPerSecondTotal).reduce(0, +) / Double(samples.count)
        series = IPThroughputSeries(
            ipAddress: ip,
            samples: samples,
            currentInBps: current?.bitsPerSecondIn ?? 0,
            currentOutBps: current?.bitsPerSecondOut ?? 0,
            currentTotalBps: current?.bitsPerSecondTotal ?? 0,
            peakInBps: samples.map(\.bitsPerSecondIn).max() ?? 0,
            peakOutBps: samples.map(\.bitsPerSecondOut).max() ?? 0,
            peakTotalBps: samples.map(\.bitsPerSecondTotal).max() ?? 0,
            averageInBps: avgIn,
            averageOutBps: avgOut,
            averageTotalBps: avgTotal
        )
    }

    private var windowSeconds: TimeInterval {
        timeWindow.seconds ?? customTimeWindowSeconds
    }
}
