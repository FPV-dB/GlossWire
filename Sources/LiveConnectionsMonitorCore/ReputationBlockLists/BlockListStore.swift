import Foundation

@MainActor
public final class ReputationBlockListStore: ObservableObject {
    public static let shared = ReputationBlockListStore()

    @Published public private(set) var subscriptions: [BlockListSubscription]
    @Published public private(set) var enabledIDs: Set<String>
    @Published public private(set) var rules: [ReputationRule] = []
    @Published public private(set) var isUpdating = false
    @Published public var statusMessage: String?

    private let defaults: UserDefaults
    private let parser = BlockListParser()
    private let cacheDirectory: URL
    private let enabledKey = "reputationBlockLists.enabledIDs"
    private let updatedKeyPrefix = "reputationBlockLists.lastUpdated."
    private let updateThrottle: TimeInterval = 12 * 60 * 60

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = support.appendingPathComponent("LiveConnectionsMonitor/BlockLists", isDirectory: true)

        let enabledKey = self.enabledKey
        let updatedKeyPrefix = self.updatedKeyPrefix
        let savedEnabled = defaults.stringArray(forKey: enabledKey)
        self.enabledIDs = savedEnabled.map(Set.init) ?? Set(ReputationBlockListCatalog.subscriptions.filter(\.isEnabledByDefault).map(\.id))
        self.subscriptions = ReputationBlockListCatalog.subscriptions.map {
            $0.with(lastUpdated: defaults.object(forKey: updatedKeyPrefix + $0.id) as? Date)
        }
        loadCachedIndex()
    }

    public func isEnabled(_ id: String) -> Bool {
        enabledIDs.contains(id)
    }

    public func setEnabled(_ id: String, enabled: Bool) {
        if enabled {
            enabledIDs.insert(id)
        } else {
            enabledIDs.remove(id)
        }
        persistEnabled()
        loadCachedIndex()
    }

    public func resetRecommendedDefaults() {
        enabledIDs = Set(ReputationBlockListCatalog.subscriptions.filter(\.isEnabledByDefault).map(\.id))
        persistEnabled()
        loadCachedIndex()
    }

    public func updateEnabledLists(force: Bool = true) async {
        await update(subscriptions.filter { enabledIDs.contains($0.id) }, force: force)
    }

    public func updateAllLists(force: Bool = true) async {
        await update(subscriptions, force: force)
    }

    public func matches(for connection: NetworkConnection) -> [ReputationMatch] {
        var candidates = Set<String>()
        if let remote = connection.remote?.address.lowercased(), !remote.isEmpty {
            candidates.insert(remote)
        }
        return matches(values: Array(candidates))
    }

    public func matches(values: [String]) -> [ReputationMatch] {
        let expanded = Set(values.flatMap(expandedCandidates))
        guard !expanded.isEmpty else { return [] }
        return rules.filter { expanded.contains($0.value) }.prefix(8).map(ReputationMatch.init)
    }

    private func update(_ targets: [BlockListSubscription], force: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        statusMessage = "Updating block lists..."
        defer { isUpdating = false }

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            statusMessage = "Could not create block list cache: \(error.localizedDescription)"
            return
        }

        var failures: [String] = []
        for subscription in targets {
            if !force, let lastUpdated = subscription.lastUpdated, Date().timeIntervalSince(lastUpdated) < updateThrottle {
                continue
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: subscription.url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                try data.write(to: cacheURL(for: subscription), options: .atomic)
                let now = Date()
                defaults.set(now, forKey: updatedKeyPrefix + subscription.id)
                subscriptions = subscriptions.map { $0.id == subscription.id ? $0.with(lastUpdated: now) : $0 }
            } catch {
                failures.append("\(subscription.name): \(error.localizedDescription)")
            }
        }
        loadCachedIndex()
        statusMessage = failures.isEmpty ? "Block lists updated." : "Some lists failed: \(failures.prefix(3).joined(separator: "; "))"
    }

    private func loadCachedIndex() {
        var nextRules: [ReputationRule] = []
        for subscription in subscriptions where enabledIDs.contains(subscription.id) {
            guard let text = try? String(contentsOf: cacheURL(for: subscription), encoding: .utf8) else { continue }
            nextRules.append(contentsOf: parser.parse(text, subscription: subscription))
        }
        rules = Array(nextRules.prefix(300_000))
    }

    private func cacheURL(for subscription: BlockListSubscription) -> URL {
        cacheDirectory.appendingPathComponent(subscription.localCachePath)
    }

    private func persistEnabled() {
        defaults.set(enabledIDs.sorted(), forKey: enabledKey)
    }

    private func expandedCandidates(_ raw: String) -> [String] {
        let cleaned = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ./"))
        guard !cleaned.isEmpty else { return [] }
        if cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == ":" }) {
            return [cleaned]
        }
        let parts = cleaned.split(separator: ".").map(String.init)
        guard parts.count > 1 else { return [cleaned] }
        return (0..<(parts.count - 1)).map { parts[$0...].joined(separator: ".") }
    }
}
