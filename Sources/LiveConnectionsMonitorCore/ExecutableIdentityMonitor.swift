import Foundation

public struct ExecutableIdentity: Identifiable, Codable, Hashable, Sendable {
    public let id: String; public let appName: String; public let path: String; public let sha256: String; public let teamIdentifier: String?; public let observedAt: Date
}
public struct ExecutableChange: Identifiable, Hashable, Sendable {
    public let id: String; public let appName: String; public let path: String; public let oldHash: String; public let newHash: String
    public let previousTeamIdentifier: String?; public let currentTeamIdentifier: String?; public let severity: String
}

public actor ExecutableIdentityStore {
    private let url: URL
    public init(url: URL? = nil) { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.url = url ?? base.appendingPathComponent("Live Connections Monitor/executable-identities.json") }
    public func load() -> [String: ExecutableIdentity] { guard let data = try? Data(contentsOf: url) else { return [:] }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return (try? decoder.decode([String: ExecutableIdentity].self, from: data)) ?? [:] }
    public func save(_ values: [String: ExecutableIdentity]) throws { guard !GlossWireLogPolicy.isDisabled else { return }; let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try encoder.encode(values).write(to: url, options: .atomic) }
}

public struct ExecutableIdentityService: Sendable {
    public init() {}
    public func scan(apps: [RunningAppNetworkSummary], previous: [String: ExecutableIdentity]) async -> ([String: ExecutableIdentity], [ExecutableChange]) {
        var current = previous, changes: [ExecutableChange] = []
        for app in apps {
            guard let path = app.executablePath, FileManager.default.isReadableFile(atPath: path), let hash = await sha256(path) else { continue }
            let key = app.bundleIdentifier ?? path
            let identity = ExecutableIdentity(id: key, appName: app.appName, path: path, sha256: hash, teamIdentifier: app.teamIdentifier, observedAt: Date())
            if let old = previous[key], old.sha256 != hash {
                let severity = app.teamIdentifier == nil ? "Review: unsigned or signer unavailable" : old.teamIdentifier != app.teamIdentifier ? "Attention: signer changed" : "Signed executable updated"
                changes.append(ExecutableChange(id: key, appName: app.appName, path: path, oldHash: old.sha256, newHash: hash, previousTeamIdentifier: old.teamIdentifier, currentTeamIdentifier: app.teamIdentifier, severity: severity))
            }
            current[key] = identity
        }
        return (current, changes.sorted { $0.appName < $1.appName })
    }
    private func sha256(_ path: String) async -> String? { guard let result = try? await CommandRunner().run("/usr/bin/shasum", arguments: ["-a", "256", path]), result.exitCode == 0 else { return nil }; return result.output.split(separator: " ").first.map(String.init) }
}

@MainActor public final class ExecutableIdentityViewModel: ObservableObject {
    @Published public private(set) var changes: [ExecutableChange] = []; @Published public private(set) var identities: [String: ExecutableIdentity] = [:]; @Published public private(set) var scanning = false; @Published public var message: String?
    private let store: ExecutableIdentityStore
    public init(store: ExecutableIdentityStore = ExecutableIdentityStore()) { self.store = store }
    public func scan(apps: [RunningAppNetworkSummary]) async { guard !scanning else { return }; scanning = true; let previous = await store.load(); let result = await ExecutableIdentityService().scan(apps: apps, previous: previous); identities = result.0; changes = result.1; do { try await store.save(result.0); message = GlossWireLogPolicy.isDisabled ? "Disable all logs is on; identities were checked but the new baseline was not saved." : "Checked \(result.0.count) executable identities." } catch { message = error.localizedDescription }; scanning = false }
}
