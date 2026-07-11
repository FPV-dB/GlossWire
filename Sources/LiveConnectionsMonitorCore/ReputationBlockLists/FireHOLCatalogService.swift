import Foundation

public struct FireHOLCatalogService: Sendable {
    private struct Summary: Decodable {
        let ipset: String
        let category: String
        let maintainer: String
        let ips: Int
    }

    private struct GitHubTree: Decodable {
        struct Entry: Decodable {
            let path: String
            let type: String
        }
        let tree: [Entry]
    }

    public init() {}

    public func subscriptions() async throws -> [BlockListSubscription] {
        let summaryURL = URL(string: "https://iplists.firehol.org/all-ipsets.json")!
        let treeURL = URL(string: "https://api.github.com/repos/firehol/blocklist-ipsets/git/trees/master?recursive=1")!
        async let summaryData = download(summaryURL)
        async let treeData = download(treeURL)
        let (summaryPayload, treePayload) = try await (summaryData, treeData)
        let summaries = try JSONDecoder().decode([Summary].self, from: summaryPayload)
        let tree = try JSONDecoder().decode(GitHubTree.self, from: treePayload)
        let compatibleFiles = Dictionary(uniqueKeysWithValues: tree.tree.compactMap { entry -> (String, String)? in
            guard entry.type == "blob", !entry.path.contains("/"), entry.path.hasSuffix(".ipset") || entry.path.hasSuffix(".netset") else { return nil }
            return ((entry.path as NSString).deletingPathExtension, entry.path)
        })

        return summaries.compactMap { summary in
            guard !["ipsum_3", "ipsum_4"].contains(summary.ipset), let file = compatibleFiles[summary.ipset] else { return nil }
            let id = "firehol-catalog-\(summary.ipset.replacingOccurrences(of: "_", with: "-"))"
            guard let url = URL(string: "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/\(file)") else { return nil }
            return BlockListSubscription(
                id: id,
                name: "FireHOL · \(displayName(summary.ipset))",
                category: category(summary.category),
                url: url,
                description: "\(summary.maintainer) · \(summary.ips.formatted()) unique IPv4 addresses · FireHOL category: \(summary.category).",
                isEnabledByDefault: false,
                localCachePath: "\(id).txt",
                listType: .ipList
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("LiveConnectionsMonitor/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    private func displayName(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").split(separator: " ").map { word in
            let upper = word.uppercased()
            return ["IP", "IPS", "SSL", "SSH", "HTTP", "DNS", "TOR", "C2"].contains(upper) ? upper : word.capitalized
        }.joined(separator: " ")
    }

    private func category(_ value: String) -> ReputationBlockListCategory {
        switch value.lowercased() {
        case "attacks": .attacks
        case "abuse": .abuse
        case "anonymizers": .anonymizers
        case "organizations": .organizations
        case "reputation": .reputation
        case "spam": .spam
        case "malware": .malware
        case "unroutable": .unroutable
        case "geolocation": .geolocation
        default: .miscellaneous
        }
    }
}
