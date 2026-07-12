import Foundation

public struct LocalNetworkReport: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID; public let periodStart: Date; public let periodEnd: Date; public let generatedAt: Date; public let observations: Int
    public let processes: Int; public let destinations: Int; public let countries: Int; public let blocked: Int; public let newProcesses: [String]; public let journal: String
}
public actor LocalNetworkReportStore {
    private let url: URL
    public init(url: URL? = nil) { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.url = url ?? base.appendingPathComponent("Live Connections Monitor/local-network-reports.json") }
    public func load() -> [LocalNetworkReport] { guard let data = try? Data(contentsOf: url) else { return [] }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return (try? decoder.decode([LocalNetworkReport].self, from: data)) ?? [] }
    public func save(_ report: LocalNetworkReport) throws { guard !GlossWireLogPolicy.isDisabled else { return }; var values = load().filter { !Calendar.current.isDate($0.periodStart, inSameDayAs: report.periodStart) }; values.insert(report, at: 0); if values.count > 366 { values.removeLast(values.count - 366) }; let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try encoder.encode(values).write(to: url, options: .atomic) }
}
public struct LocalNetworkReportGenerator: Sendable {
    public init() {}
    public func daily(records: [AppConnectionRecord], day: Date = Date()) -> LocalNetworkReport {
        let calendar = Calendar.current, start = calendar.startOfDay(for: day), end = calendar.date(byAdding: .day, value: 1, to: start)!
        let current = records.filter { $0.timestamp >= start && $0.timestamp < end }, prior = records.filter { $0.timestamp < start }
        return LocalNetworkReport(id: UUID(), periodStart: start, periodEnd: end, generatedAt: Date(), observations: current.count,
            processes: Set(current.map(\.appBundleIdentifier)).count, destinations: Set(current.compactMap(\.remoteAddress)).count,
            countries: Set(current.compactMap(\.countryCode)).count, blocked: current.filter { $0.ruleAction == .blocked || $0.ruleAction == .manualBlock }.count,
            newProcesses: Array(Set(current.map(\.appBundleIdentifier)).subtracting(Set(prior.map(\.appBundleIdentifier)))).sorted(),
            journal: NetworkIntelligenceAnalyzer().journal(records: records, day: day))
    }
}

@MainActor public final class InvestigationWorkflowViewModel: ObservableObject {
    @Published public private(set) var reports: [LocalNetworkReport] = []; @Published public var retentionDays = 30; @Published public private(set) var retainedCount = 0; @Published public var message: String?
    private let reportsStore: LocalNetworkReportStore
    public init(reportsStore: LocalNetworkReportStore = LocalNetworkReportStore()) { self.reportsStore = reportsStore; retentionDays = UserDefaults.standard.object(forKey: "history.retentionDays") as? Int ?? 30 }
    public func load(network: ApplicationNetworkViewModel) async { reports = await reportsStore.load(); retainedCount = await network.retainedHistoryCount() }
    public func generateDailyIfNeeded(records: [AppConnectionRecord]) async { reports = await reportsStore.load(); if !(reports.first.map { Calendar.current.isDateInToday($0.periodStart) } ?? false) { try? await reportsStore.save(LocalNetworkReportGenerator().daily(records: records)); reports = await reportsStore.load() } }
    public func generate(records: [AppConnectionRecord]) async { try? await reportsStore.save(LocalNetworkReportGenerator().daily(records: records)); reports = await reportsStore.load() }
    public func applyRetention(network: ApplicationNetworkViewModel) async { UserDefaults.standard.set(retentionDays, forKey: "history.retentionDays"); if let removed = await network.pruneHistory(retainingDays: retentionDays) { retainedCount = await network.retainedHistoryCount(); message = "Removed \(removed.formatted()) records and compacted the history database." } }
}
