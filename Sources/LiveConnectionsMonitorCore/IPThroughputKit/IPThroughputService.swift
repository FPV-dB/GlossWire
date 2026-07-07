import Foundation

public actor IPThroughputService {
    private struct CounterSnapshot: Sendable {
        var date: Date
        var bytesIn: UInt64
        var bytesOut: UInt64
    }

    private var previous: [String: CounterSnapshot] = [:]
    private var persistedURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return support
            .appendingPathComponent("Live Connections Monitor", isDirectory: true)
            .appendingPathComponent("ip-throughput-history.json")
    }

    public init() {}

    public func sample(ip: String, connections: [NetworkConnection]) -> ThroughputSample {
        let now = Date()
        let matching = connections.filter { $0.remote?.address == ip || $0.local.address == ip }
        let bytesIn = matching.reduce(UInt64(0)) { $0 + ($1.bytesIn ?? 0) }
        let bytesOut = matching.reduce(UInt64(0)) { $0 + ($1.bytesOut ?? 0) }
        let previousSnapshot = previous[ip]
        previous[ip] = CounterSnapshot(date: now, bytesIn: bytesIn, bytesOut: bytesOut)

        guard let previousSnapshot else {
            return ThroughputSample(timestamp: now, ipAddress: ip, bytesIn: bytesIn, bytesOut: bytesOut, bytesTotal: bytesIn + bytesOut, bitsPerSecondIn: 0, bitsPerSecondOut: 0, bitsPerSecondTotal: 0)
        }

        let elapsed = max(now.timeIntervalSince(previousSnapshot.date), 0.001)
        let deltaIn = bytesIn >= previousSnapshot.bytesIn ? bytesIn - previousSnapshot.bytesIn : 0
        let deltaOut = bytesOut >= previousSnapshot.bytesOut ? bytesOut - previousSnapshot.bytesOut : 0
        let inBps = Double(deltaIn * 8) / elapsed
        let outBps = Double(deltaOut * 8) / elapsed
        return ThroughputSample(timestamp: now, ipAddress: ip, bytesIn: bytesIn, bytesOut: bytesOut, bytesTotal: bytesIn + bytesOut, bitsPerSecondIn: inBps, bitsPerSecondOut: outBps, bitsPerSecondTotal: inBps + outBps)
    }

    public func loadPersisted() throws -> [String: [ThroughputSample]] {
        guard FileManager.default.fileExists(atPath: persistedURL.path) else { return [:] }
        let data = try Data(contentsOf: persistedURL)
        return try JSONDecoder().decode([String: [ThroughputSample]].self, from: data)
    }

    public func persist(_ history: [String: [ThroughputSample]]) throws {
        try FileManager.default.createDirectory(at: persistedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(history).write(to: persistedURL, options: .atomic)
    }
}
