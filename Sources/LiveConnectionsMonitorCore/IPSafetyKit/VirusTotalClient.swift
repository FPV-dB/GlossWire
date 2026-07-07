import Foundation

public struct VirusTotalClient: Sendable {
    public init() {}

    public func check(ip: String, apiKey: String) async -> IPSafetyProviderResult {
        guard !apiKey.isEmpty else { return IPSafetyProviderResult(provider: "VirusTotal", status: "Skipped", detail: "No API key configured.") }
        do {
            var request = URLRequest(url: URL(string: "https://www.virustotal.com/api/v3/ip_addresses/\(ip)")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let dataObject = json?["data"] as? [String: Any]
            let attributes = dataObject?["attributes"] as? [String: Any]
            let stats = attributes?["last_analysis_stats"] as? [String: Any]
            let malicious = stats?["malicious"] as? Int ?? 0
            return IPSafetyProviderResult(provider: "VirusTotal", status: "\(malicious) malicious", detail: "Malicious detections: \(malicious)")
        } catch {
            return IPSafetyProviderResult(provider: "VirusTotal", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
