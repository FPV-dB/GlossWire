import Foundation

public actor IPSafetyCache {
    private let fileURL: URL
    private let lifetime: TimeInterval

    public init(lifetime: TimeInterval = 24 * 60 * 60) {
        self.lifetime = lifetime
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        fileURL = support
            .appendingPathComponent("Live Connections Monitor", isDirectory: true)
            .appendingPathComponent("ip-safety-cache.json")
    }

    public func report(for ip: String) throws -> IPSafetyReport? {
        guard let report = try load()[ip], Date().timeIntervalSince(report.lastChecked) < lifetime else { return nil }
        var cached = report
        cached.fromCache = true
        return cached
    }

    public func store(_ report: IPSafetyReport) throws {
        var values = try load()
        var stored = report
        stored.fromCache = false
        values[report.ip] = stored
        try save(values)
    }

    private func load() throws -> [String: IPSafetyReport] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: IPSafetyReport].self, from: data)
    }

    private func save(_ values: [String: IPSafetyReport]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(values).write(to: fileURL, options: .atomic)
    }
}
