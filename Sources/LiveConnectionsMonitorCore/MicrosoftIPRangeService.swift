import Foundation

public struct MicrosoftIPRangeResult: Sendable {
    public let ranges: [String]
    public let fetchedAt: Date
}

public enum MicrosoftIPRangeError: LocalizedError {
    case invalidResponse(URL)
    case invalidDocument
    case noRanges

    public var errorDescription: String? {
        switch self {
        case let .invalidResponse(url):
            return "Microsoft returned an invalid IP range response from \(url.absoluteString)."
        case .invalidDocument:
            return "Microsoft's IP range feed could not be decoded."
        case .noRanges:
            return "Microsoft's published feed did not contain any IP ranges."
        }
    }
}

public struct MicrosoftIPRangeService: Sendable {
    public static let managedBlocklistName = "Known Microsoft IP Ranges"
    public static let azureServiceTagsURL = URL(string: "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519")!

    public init() {}

    public func fetchAllKnownRanges() async throws -> MicrosoftIPRangeResult {
        let landingPage = try await fetch(Self.azureServiceTagsURL)
        guard let manifestURL = Self.extractManifestURL(from: landingPage) else {
            throw MicrosoftIPRangeError.invalidDocument
        }
        let manifest = try await fetch(manifestURL)
        let ranges = Set(try parse(data: manifest))
        guard !ranges.isEmpty else { throw MicrosoftIPRangeError.noRanges }
        return MicrosoftIPRangeResult(ranges: ranges.sorted(), fetchedAt: Date())
    }

    public func parse(data: Data) throws -> [String] {
        let document = try JSONDecoder().decode(ServiceTagsDocument.self, from: data)
        return document.values.flatMap(\.properties.addressPrefixes)
    }

    public static func extractManifestURL(from html: Data) -> URL? {
        guard let text = String(data: html, encoding: .utf8) else { return nil }
        let pattern = #"https://download\.microsoft\.com/download/[^\"]+?ServiceTags_Public_[0-9]+\.json"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return URL(string: String(text[range]))
    }

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw MicrosoftIPRangeError.invalidResponse(url)
        }
        return data
    }
}

private struct ServiceTagsDocument: Decodable {
    let values: [ServiceTagEntry]
}

private struct ServiceTagEntry: Decodable {
    let properties: ServiceTagProperties
}

private struct ServiceTagProperties: Decodable {
    let addressPrefixes: [String]
}
