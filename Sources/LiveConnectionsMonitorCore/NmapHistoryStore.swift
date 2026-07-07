import Foundation

public actor NmapHistoryStore {
    private let fileURL: URL
    private let favouritesURL: URL

    public init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = support.appendingPathComponent("Live Connections Monitor", isDirectory: true)
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = directory.appendingPathComponent("nmap-scan-history.json")
        }
        self.favouritesURL = directory.appendingPathComponent("nmap-favourite-profiles.json")
    }

    public func load() throws -> [NmapScanHistoryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([NmapScanHistoryItem].self, from: data)
    }

    public func append(_ item: NmapScanHistoryItem, limit: Int = 200) throws {
        var items = try load()
        items.insert(item, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        try save(items)
    }

    public func clear() throws {
        try save([])
    }

    private func save(_ items: [NmapScanHistoryItem]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadFavourites() throws -> [NmapFavouriteProfile] {
        guard FileManager.default.fileExists(atPath: favouritesURL.path) else { return [] }
        let data = try Data(contentsOf: favouritesURL)
        return try JSONDecoder().decode([NmapFavouriteProfile].self, from: data)
    }

    public func saveFavourites(_ profiles: [NmapFavouriteProfile]) throws {
        try FileManager.default.createDirectory(at: favouritesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: favouritesURL, options: .atomic)
    }
}
