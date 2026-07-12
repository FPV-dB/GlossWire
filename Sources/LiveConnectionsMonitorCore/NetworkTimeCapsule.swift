import Foundation

public struct NetworkTimeCapsuleSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID; public let timestamp: Date; public let installedApplications: [String]; public let observedProcesses: [String]
    public let activeDestinations: [String]; public let observedLANDevices: [String]; public let wifiNetwork: String?; public let gateway: String?
    public let ipv4Available: Bool; public let ipv6Available: Bool; public let latencyMS: Double?; public let packetLossPercent: Double?
    public let dnsResponseMS: Double?; public let routingTable: String; public let unavailableEvidence: [String]
}

public actor NetworkTimeCapsuleStore {
    private let url: URL
    public init(url: URL? = nil) { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.url = url ?? base.appendingPathComponent("Live Connections Monitor/network-time-capsule.json") }
    public func load() -> [NetworkTimeCapsuleSnapshot] { guard let data = try? Data(contentsOf: url) else { return [] }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return (try? decoder.decode([NetworkTimeCapsuleSnapshot].self, from: data)) ?? [] }
    public func save(_ snapshot: NetworkTimeCapsuleSnapshot) throws { guard !GlossWireLogPolicy.isDisabled else { return }; var values = load(); values.append(snapshot); values.sort { $0.timestamp > $1.timestamp }; let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try encoder.encode(values).write(to: url, options: .atomic) }
}

public struct NetworkTimeCapsuleService: Sendable {
    public init() {}
    public func capture(records: [AppConnectionRecord], weather: InternetWeatherSample?) async -> NetworkTimeCapsuleSnapshot {
        async let routes = CommandRunner().run("/usr/sbin/netstat", arguments: ["-rn"])
        async let wifi = CommandRunner().run("/usr/sbin/networksetup", arguments: ["-getairportnetwork", "en0"])
        let routeResult = try? await routes, wifiResult = try? await wifi
        let topology = NetworkInvestigationAnalyzer().topology(records: records)
        return NetworkTimeCapsuleSnapshot(id: UUID(), timestamp: Date(), installedApplications: installedApplications(),
            observedProcesses: Set(records.map(\.appBundleIdentifier)).sorted(), activeDestinations: Set(records.compactMap(\.remoteAddress)).sorted(),
            observedLANDevices: topology.map { "\($0.name) [\($0.address)]" }, wifiNetwork: parseWiFi(wifiResult?.output ?? ""), gateway: weather?.gateway,
            ipv4Available: weather?.ipv4Available ?? false, ipv6Available: weather?.ipv6Available ?? false, latencyMS: weather?.latencyMS,
            packetLossPercent: weather?.packetLossPercent, dnsResponseMS: weather?.dnsResponseMS, routingTable: routeResult?.output ?? "Unavailable",
            unavailableEvidence: ["DNS cache contents and requesting process", "Public IP address", "Packet payloads", "Per-flow bytes when unsupported by provider"])
    }
    public func parseWiFi(_ text: String) -> String? { guard !text.localizedCaseInsensitiveContains("not associated") else { return nil }; return text.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 } }
    private func installedApplications() -> [String] { let fm = FileManager.default; let directories = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]; return Set(directories.flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [] }.filter { $0.pathExtension == "app" }.map { $0.deletingPathExtension().lastPathComponent }).sorted() }
}

@MainActor public final class NetworkTimeCapsuleViewModel: ObservableObject {
    @Published public private(set) var snapshots: [NetworkTimeCapsuleSnapshot] = []; @Published public private(set) var capturing = false; @Published public var error: String?
    private let store: NetworkTimeCapsuleStore
    public init(store: NetworkTimeCapsuleStore = NetworkTimeCapsuleStore()) { self.store = store }
    public func load() async { snapshots = await store.load() }
    public func capture(records: [AppConnectionRecord]) async { guard !capturing else { return }; capturing = true; let weather = await InternetWeatherStore().load().last; let snapshot = await NetworkTimeCapsuleService().capture(records: records, weather: weather); do { try await store.save(snapshot); snapshots = await store.load(); if GlossWireLogPolicy.isDisabled { error = "Disable all logs is on; the snapshot was observed but not saved." } } catch { self.error = error.localizedDescription }; capturing = false }
    public func captureDailyIfNeeded(records: [AppConnectionRecord]) async { await load(); guard snapshots.first.map({ !Calendar.current.isDateInToday($0.timestamp) }) ?? true else { return }; await capture(records: records) }
}
