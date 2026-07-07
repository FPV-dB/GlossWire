import Foundation

public enum IPSafetyRiskLabel: String, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    case unknown = "Unknown"

    public static func label(for score: Int) -> IPSafetyRiskLabel {
        switch score {
        case 0...20: .low
        case 21...50: .medium
        case 51...80: .high
        case 81...100: .critical
        default: .unknown
        }
    }
}

public enum IPAddressKind: String, Codable, Sendable {
    case publicIPv4
    case privateLAN
    case loopback
    case reserved
    case multicast
    case invalid
    case unsupported
}

public struct IPSafetyProviderResult: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var provider: String
    public var status: String
    public var detail: String
    public var error: String?
}

public struct DNSBLListing: Identifiable, Codable, Hashable, Sendable {
    public var id: String { provider }
    public var provider: String
    public var listed: Bool
    public var response: String?
    public var error: String?
}

public struct IPSafetyReport: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var ip: String
    public var addressKind: IPAddressKind
    public var riskScore: Int
    public var riskLabel: IPSafetyRiskLabel
    public var summary: String
    public var providerResults: [IPSafetyProviderResult]
    public var dnsblListings: [DNSBLListing]
    public var asn: String?
    public var isp: String?
    public var reverseDNS: String?
    public var rdapOrganisation: String?
    public var countryRegion: String?
    public var torExitNode: Bool?
    public var datacentreHint: String?
    public var lastChecked: Date
    public var fromCache: Bool
}

public struct IPSafetyProviderSettings: Sendable {
    public var enableDNSBLChecks: Bool
    public var enableTorExitNodeCheck: Bool
    public var enableASNLookup: Bool
    public var enableRDAPLookup: Bool
    public var enableAbuseIPDB: Bool
    public var enableVirusTotal: Bool
    public var enableGreyNoise: Bool
    public var respectProviderRateLimits: Bool

    public init(
        enableDNSBLChecks: Bool = true,
        enableTorExitNodeCheck: Bool = true,
        enableASNLookup: Bool = true,
        enableRDAPLookup: Bool = true,
        enableAbuseIPDB: Bool = false,
        enableVirusTotal: Bool = false,
        enableGreyNoise: Bool = false,
        respectProviderRateLimits: Bool = true
    ) {
        self.enableDNSBLChecks = enableDNSBLChecks
        self.enableTorExitNodeCheck = enableTorExitNodeCheck
        self.enableASNLookup = enableASNLookup
        self.enableRDAPLookup = enableRDAPLookup
        self.enableAbuseIPDB = enableAbuseIPDB
        self.enableVirusTotal = enableVirusTotal
        self.enableGreyNoise = enableGreyNoise
        self.respectProviderRateLimits = respectProviderRateLimits
    }
}

public enum IPSafetyAddressClassifier {
    public static func classify(_ rawValue: String) -> IPAddressKind {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "localhost" || value == "::1" { return .loopback }
        if value.contains(":") { return .unsupported }
        let octets = value.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return .invalid }
        if octets[0] == 127 { return .loopback }
        if octets[0] == 10 || (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 192 && octets[1] == 168) { return .privateLAN }
        if octets[0] == 0 || octets[0] >= 240 || (octets[0] == 169 && octets[1] == 254) { return .reserved }
        if (224...239).contains(octets[0]) { return .multicast }
        return .publicIPv4
    }

    public static func reversedIPv4(_ ip: String) -> String? {
        let octets = ip.split(separator: ".").map(String.init)
        guard octets.count == 4 else { return nil }
        return octets.reversed().joined(separator: ".")
    }
}
