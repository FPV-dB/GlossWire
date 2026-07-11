import Foundation

public struct TorRelayRangeResult: Sendable {
    public let ranges: [String]
    public let publishedAt: Date?
    public let fetchedAt: Date
}

public struct TorRelayRangeService: Sendable {
    public static let managedBlocklistName = "Known Tor Public Relays"
    private let endpoint = URL(string: "https://onionoo.torproject.org/summary?running=true&type=relay&fields=a,r")!

    public init() {}

    public func fetchRunningRelayRanges() async throws -> TorRelayRangeResult {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 45
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("GlossWire/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let document = try JSONDecoder().decode(OnionooSummary.self, from: data)
        let ranges = Set(document.relays.filter(\.running).flatMap(\.addresses).compactMap(normalizedAddress))
        guard !ranges.isEmpty else { throw URLError(.zeroByteResource) }
        return TorRelayRangeResult(
            ranges: ranges.sorted(),
            publishedAt: Self.dateFormatter.date(from: document.relaysPublished),
            fetchedAt: Date()
        )
    }

    private func normalizedAddress(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
        guard !value.isEmpty else { return nil }
        return value
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct OnionooSummary: Decodable {
    let relaysPublished: String
    let relays: [OnionooRelay]
    enum CodingKeys: String, CodingKey { case relaysPublished = "relays_published"; case relays }
}

private struct OnionooRelay: Decodable {
    let addresses: [String]
    let running: Bool
    enum CodingKeys: String, CodingKey { case addresses = "a"; case running = "r" }
}
