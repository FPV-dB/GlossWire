import SwiftUI

public struct IPSafetySettingsView: View {
    @AppStorage("ipSafety.enableDNSBLChecks") private var enableDNSBLChecks = true
    @AppStorage("ipSafety.enableTorExitNodeCheck") private var enableTorExitNodeCheck = true
    @AppStorage("ipSafety.enableASNLookup") private var enableASNLookup = true
    @AppStorage("ipSafety.enableRDAPLookup") private var enableRDAPLookup = true
    @AppStorage("ipSafety.enableAbuseIPDB") private var enableAbuseIPDB = false
    @AppStorage("ipSafety.enableVirusTotal") private var enableVirusTotal = false
    @AppStorage("ipSafety.enableGreyNoise") private var enableGreyNoise = false
    @AppStorage("ipSafety.respectProviderRateLimits") private var respectProviderRateLimits = true

    @State private var abuseKey = KeychainStore.get(account: "abuseipdb")
    @State private var vtKey = KeychainStore.get(account: "virustotal")
    @State private var greyKey = KeychainStore.get(account: "greynoise")

    public init() {}

    public var body: some View {
        Section("IP Safety Providers") {
            Toggle("Enable DNSBL checks", isOn: $enableDNSBLChecks)
            Toggle("Enable Tor exit node check", isOn: $enableTorExitNodeCheck)
            Toggle("Enable ASN lookup", isOn: $enableASNLookup)
            Toggle("Enable RDAP lookup", isOn: $enableRDAPLookup)
            Toggle("Enable AbuseIPDB", isOn: $enableAbuseIPDB)
            SecureField("AbuseIPDB API key", text: $abuseKey).onChange(of: abuseKey) { _, value in try? KeychainStore.set(value, account: "abuseipdb") }
            Toggle("Enable VirusTotal", isOn: $enableVirusTotal)
            SecureField("VirusTotal API key", text: $vtKey).onChange(of: vtKey) { _, value in try? KeychainStore.set(value, account: "virustotal") }
            Toggle("Enable GreyNoise", isOn: $enableGreyNoise)
            SecureField("GreyNoise API key", text: $greyKey).onChange(of: greyKey) { _, value in try? KeychainStore.set(value, account: "greynoise") }
            Toggle("Respect provider rate limits", isOn: $respectProviderRateLimits)
            Text("Only the selected IP is checked. API keys are stored in Keychain. Reputation is advisory only: review before blocking.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    public static func currentSettings() -> IPSafetyProviderSettings {
        IPSafetyProviderSettings(
            enableDNSBLChecks: UserDefaults.standard.object(forKey: "ipSafety.enableDNSBLChecks") as? Bool ?? true,
            enableTorExitNodeCheck: UserDefaults.standard.object(forKey: "ipSafety.enableTorExitNodeCheck") as? Bool ?? true,
            enableASNLookup: UserDefaults.standard.object(forKey: "ipSafety.enableASNLookup") as? Bool ?? true,
            enableRDAPLookup: UserDefaults.standard.object(forKey: "ipSafety.enableRDAPLookup") as? Bool ?? true,
            enableAbuseIPDB: UserDefaults.standard.bool(forKey: "ipSafety.enableAbuseIPDB"),
            enableVirusTotal: UserDefaults.standard.bool(forKey: "ipSafety.enableVirusTotal"),
            enableGreyNoise: UserDefaults.standard.bool(forKey: "ipSafety.enableGreyNoise"),
            respectProviderRateLimits: UserDefaults.standard.object(forKey: "ipSafety.respectProviderRateLimits") as? Bool ?? true
        )
    }
}
