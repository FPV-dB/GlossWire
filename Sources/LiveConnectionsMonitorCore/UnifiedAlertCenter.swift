import Foundation

public enum UnifiedAlertSeverity: String, CaseIterable, Codable, Sendable { case info = "Info", notice = "Notice", warning = "Warning", critical = "Critical"; public var rank: Int { switch self { case .info: 0; case .notice: 1; case .warning: 2; case .critical: 3 } } }
public enum UnifiedAlertStatus: String, CaseIterable, Codable, Sendable { case open = "Open", acknowledged = "Acknowledged", resolved = "Resolved" }
public struct UnifiedAlert: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID; public let deduplicationKey: String; public let createdAt: Date; public var updatedAt: Date; public let severity: UnifiedAlertSeverity
    public let category: String; public let title: String; public let detail: String; public let process: String?; public var occurrenceCount: Int; public var status: UnifiedAlertStatus
}
public struct AlertMute: Codable, Hashable, Sendable { public let process: String; public let until: Date }

public actor UnifiedAlertStore {
    private let alertsURL: URL; private let mutesURL: URL
    public init(directory: URL? = nil) { let base = directory ?? ((FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser).appendingPathComponent("Live Connections Monitor", isDirectory: true)); alertsURL = base.appendingPathComponent("unified-alerts.json"); mutesURL = base.appendingPathComponent("alert-mutes.json") }
    public func load() -> [UnifiedAlert] { decode([UnifiedAlert].self, from: alertsURL) ?? [] }
    public func mutes(now: Date = Date()) -> [AlertMute] { (decode([AlertMute].self, from: mutesURL) ?? []).filter { $0.until > now } }
    public func record(severity: UnifiedAlertSeverity, category: String, title: String, detail: String, process: String?, key: String, now: Date = Date(), deduplicationWindow: TimeInterval = 3600) throws {
        guard !GlossWireLogPolicy.isDisabled else { return }; if let process, mutes(now: now).contains(where: { $0.process == process }) { return }
        var alerts = load()
        if let index = alerts.firstIndex(where: { $0.deduplicationKey == key && now.timeIntervalSince($0.updatedAt) <= deduplicationWindow && $0.status != .resolved }) { alerts[index].updatedAt = now; alerts[index].occurrenceCount += 1 }
        else { alerts.insert(UnifiedAlert(id: UUID(), deduplicationKey: key, createdAt: now, updatedAt: now, severity: severity, category: category, title: title, detail: detail, process: process, occurrenceCount: 1, status: .open), at: 0) }
        if alerts.count > 5_000 { alerts.removeLast(alerts.count - 5_000) }; try encode(alerts, to: alertsURL)
    }
    public func setStatus(id: UUID, status: UnifiedAlertStatus) throws { var alerts = load(); guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }; alerts[index].status = status; alerts[index].updatedAt = Date(); try encode(alerts, to: alertsURL) }
    public func mute(process: String, hours: Double = 24) throws { var values = mutes().filter { $0.process != process }; values.append(AlertMute(process: process, until: Date().addingTimeInterval(hours * 3600))); try encode(values, to: mutesURL) }
    public func unmute(process: String) throws { try encode(mutes().filter { $0.process != process }, to: mutesURL) }
    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? { guard let data = try? Data(contentsOf: url) else { return nil }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return try? decoder.decode(type, from: data) }
    private func encode<T: Encodable>(_ value: T, to url: URL) throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(value).write(to: url, options: .atomic) }
}

public struct UnifiedAlertEvaluator: Sendable {
    public init() {}
    public func evaluate(records: [AppConnectionRecord], samples: [String: [AppTrafficSample]], store: UnifiedAlertStore, now: Date = Date()) async throws {
        let recentStart = now.addingTimeInterval(-3600), older = records.filter { $0.timestamp < recentStart }, recent = records.filter { $0.timestamp >= recentStart }
        let knownApps = Set(older.map(\.appBundleIdentifier)), knownDestinations = Set(older.compactMap(\.remoteAddress))
        for app in Set(recent.map(\.appBundleIdentifier)).subtracting(knownApps) { try await store.record(severity: .notice, category: "New process", title: "New process accessed the network", detail: "\(app) first appears in the currently retained baseline.", process: app, key: "new-process:\(app)", now: now) }
        for destination in Set(recent.compactMap(\.remoteAddress)).subtracting(knownDestinations).prefix(100) { try await store.record(severity: .info, category: "New destination", title: "Previously unseen destination", detail: destination, process: recent.first(where: { $0.remoteAddress == destination })?.appBundleIdentifier, key: "new-destination:\(destination)", now: now) }
        let analyzer = NetworkIntelligenceAnalyzer()
        for signal in analyzer.behaviourSignals(records: records) { try await store.record(severity: signal.kind == .beacon ? .warning : .notice, category: signal.kind.rawValue, title: signal.kind.rawValue, detail: signal.detail, process: signal.process, key: signal.id, now: now) }
        for spike in analyzer.uploadSpikes(samplesByApp: samples) { try await store.record(severity: .warning, category: "Upload spike", title: "Unusual process upload rate", detail: "Current \(Int(spike.currentBps)) B/s, \(spike.multiplier.formatted(.number.precision(.fractionLength(1))))x baseline.", process: spike.id, key: "upload-spike:\(spike.id)", now: now, deduplicationWindow: 900) }
    }
}

@MainActor public final class UnifiedAlertCenterViewModel: ObservableObject {
    @Published public private(set) var alerts: [UnifiedAlert] = []; @Published public private(set) var mutes: [AlertMute] = []; @Published public var minimumSeverity = UnifiedAlertSeverity.info; @Published public var statusFilter: UnifiedAlertStatus? = .open; @Published public var search = ""; @Published public var error: String?
    private let store: UnifiedAlertStore
    public init(store: UnifiedAlertStore = UnifiedAlertStore()) { self.store = store }
    public var visibleAlerts: [UnifiedAlert] { alerts.filter { $0.severity.rank >= minimumSeverity.rank && (statusFilter == nil || $0.status == statusFilter) && (search.isEmpty || [$0.title, $0.detail, $0.process ?? "", $0.category].joined(separator: " ").localizedCaseInsensitiveContains(search)) } }
    public func reload() async { alerts = await store.load(); mutes = await store.mutes() }
    public func evaluate(records: [AppConnectionRecord], samples: [String: [AppTrafficSample]]) async { do { try await UnifiedAlertEvaluator().evaluate(records: records, samples: samples, store: store); await reload() } catch { self.error = error.localizedDescription } }
    public func setStatus(_ alert: UnifiedAlert, _ status: UnifiedAlertStatus) { Task { do { try await store.setStatus(id: alert.id, status: status); await reload() } catch { self.error = error.localizedDescription } } }
    public func mute(_ process: String) { Task { do { try await store.mute(process: process); await reload() } catch { self.error = error.localizedDescription } } }
    public func unmute(_ process: String) { Task { do { try await store.unmute(process: process); await reload() } catch { self.error = error.localizedDescription } } }
}
