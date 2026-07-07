import Foundation

public struct TorExitNodeClient: Sendable {
    public init() {}

    public func check(ip: String) async -> IPSafetyProviderResult {
        guard IPSafetyAddressClassifier.classify(ip) == .publicIPv4 else {
            return IPSafetyProviderResult(provider: "Tor Exit Nodes", status: "Skipped", detail: "Tor exit checks apply to public IPv4 addresses.")
        }
        do {
            let url = URL(string: "https://check.torproject.org/torbulkexitlist")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let body = String(data: data, encoding: .utf8) ?? ""
            let listed = Set(body.components(separatedBy: .newlines)).contains(ip)
            return IPSafetyProviderResult(provider: "Tor Exit Nodes", status: listed ? "Listed" : "Not listed", detail: listed ? "This IP appears in the Tor exit-node list." : "Not found in the Tor exit-node list.")
        } catch {
            return IPSafetyProviderResult(provider: "Tor Exit Nodes", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
