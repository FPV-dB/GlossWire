import Foundation

public struct RDAPClient: Sendable {
    public init() {}

    public func lookup(ip: String) async -> IPSafetyProviderResult {
        guard IPSafetyAddressClassifier.classify(ip) == .publicIPv4 else {
            return IPSafetyProviderResult(provider: "RDAP", status: "Skipped", detail: "RDAP is not applicable to local/private addresses.")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://rdap.org/ip/\(ip)")!)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let name = json?["name"] as? String
            let country = json?["country"] as? String
            let detail = [name, country].compactMap { $0 }.joined(separator: " / ")
            return IPSafetyProviderResult(provider: "RDAP", status: detail.isEmpty ? "No data" : "OK", detail: detail)
        } catch {
            return IPSafetyProviderResult(provider: "RDAP", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
