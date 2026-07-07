import Foundation

public struct GreyNoiseClient: Sendable {
    public init() {}

    public func check(ip: String, apiKey: String) async -> IPSafetyProviderResult {
        do {
            var request = URLRequest(url: URL(string: "https://api.greynoise.io/v3/community/\(ip)")!)
            if !apiKey.isEmpty { request.setValue(apiKey, forHTTPHeaderField: "key") }
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let classification = json?["classification"] as? String ?? "unknown"
            let noise = json?["noise"] as? Bool ?? false
            let name = json?["name"] as? String ?? ""
            return IPSafetyProviderResult(provider: "GreyNoise", status: classification, detail: "Noise: \(noise). \(name)")
        } catch {
            return IPSafetyProviderResult(provider: "GreyNoise", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
