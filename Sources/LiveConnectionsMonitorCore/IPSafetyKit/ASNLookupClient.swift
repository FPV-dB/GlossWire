import Foundation

public struct ASNLookupClient: Sendable {
    public init() {}

    public func lookup(ip: String) async -> IPSafetyProviderResult {
        guard IPSafetyAddressClassifier.classify(ip) == .publicIPv4,
              let reversed = IPSafetyAddressClassifier.reversedIPv4(ip) else {
            return IPSafetyProviderResult(provider: "Team Cymru ASN", status: "Skipped", detail: "ASN lookup applies to public IPv4 addresses.")
        }
        do {
            let query = "\(reversed).origin.asn.cymru.com"
            let output = try await DNSBLClient.run(executable: "/usr/bin/dig", arguments: ["+short", "TXT", query])
            let cleaned = output.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return IPSafetyProviderResult(provider: "Team Cymru ASN", status: cleaned.isEmpty ? "No data" : "OK", detail: cleaned)
        } catch {
            return IPSafetyProviderResult(provider: "Team Cymru ASN", status: "Error", detail: "", error: error.localizedDescription)
        }
    }
}
