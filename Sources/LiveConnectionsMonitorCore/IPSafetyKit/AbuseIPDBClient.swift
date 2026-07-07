import Foundation

public struct AbuseIPDBClient: Sendable {
    public init() {}

    public func check(ip: String, apiKey: String) async -> IPSafetyProviderResult {
        guard !apiKey.isEmpty else { return IPSafetyProviderResult(provider: "AbuseIPDB", status: "Skipped", detail: "No API key configured.") }
        do {
            var components = URLComponents(string: "https://api.abuseipdb.com/api/v2/check")!
            components.queryItems = [URLQueryItem(name: "ipAddress", value: ip), URLQueryItem(name: "maxAgeInDays", value: "90")]
            var request = URLRequest(url: components.url!)
            request.setValue(apiKey, forHTTPHeaderField: "Key")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let dataObject = json?["data"] as? [String: Any]
            let score = dataObject?["abuseConfidenceScore"] as? Int ?? 0
            return IPSafetyProviderResult(provider: "AbuseIPDB", status: "\(score)% confidence", detail: "Abuse confidence score: \(score)")
        } catch {
            return IPSafetyProviderResult(provider: "AbuseIPDB", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
