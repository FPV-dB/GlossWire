import Foundation

public actor IPSafetyService {
    private let cache = IPSafetyCache()
    private let dnsbl = DNSBLClient()
    private let asn = ASNLookupClient()
    private let rdap = RDAPClient()
    private let tor = TorExitNodeClient()
    private let abuse = AbuseIPDBClient()
    private let virusTotal = VirusTotalClient()
    private let greyNoise = GreyNoiseClient()

    public init() {}

    public func check(ip: String, settings: IPSafetyProviderSettings, refresh: Bool = false) async -> IPSafetyReport {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        if !refresh, let cached = try? await cache.report(for: cleanIP) {
            return cached
        }

        let kind = IPSafetyAddressClassifier.classify(cleanIP)
        if kind != .publicIPv4 {
            let report = localReport(ip: cleanIP, kind: kind)
            try? await cache.store(report)
            return report
        }

        async let reverseDNS = reverseDNS(ip: cleanIP)
        async let dnsblListings = settings.enableDNSBLChecks ? dnsbl.check(ip: cleanIP) : []
        async let asnResult = settings.enableASNLookup ? asn.lookup(ip: cleanIP) : skipped("Team Cymru ASN")
        async let rdapResult = settings.enableRDAPLookup ? rdap.lookup(ip: cleanIP) : skipped("RDAP")
        async let torResult = settings.enableTorExitNodeCheck ? tor.check(ip: cleanIP) : skipped("Tor Exit Nodes")
        async let abuseResult = settings.enableAbuseIPDB ? abuse.check(ip: cleanIP, apiKey: KeychainStore.get(account: "abuseipdb")) : skipped("AbuseIPDB")
        async let vtResult = settings.enableVirusTotal ? virusTotal.check(ip: cleanIP, apiKey: KeychainStore.get(account: "virustotal")) : skipped("VirusTotal")
        async let gnResult = settings.enableGreyNoise ? greyNoise.check(ip: cleanIP, apiKey: KeychainStore.get(account: "greynoise")) : skipped("GreyNoise")

        let providerResults = await [asnResult, rdapResult, torResult, abuseResult, vtResult, gnResult]
        let listings = await dnsblListings
        let ptr = await reverseDNS
        let report = buildReport(ip: cleanIP, kind: kind, reverseDNS: ptr, dnsblListings: listings, providerResults: providerResults)
        try? await cache.store(report)
        return report
    }

    private func localReport(ip: String, kind: IPAddressKind) -> IPSafetyReport {
        let summary = kind == .privateLAN || kind == .loopback
            ? "This is a private LAN address. Public reputation services are not applicable."
            : "This address is reserved or unsupported. Public reputation services are not applicable."
        return IPSafetyReport(
            ip: ip,
            addressKind: kind,
            riskScore: 0,
            riskLabel: kind == .invalid ? .unknown : .low,
            summary: summary,
            providerResults: [],
            dnsblListings: [],
            asn: nil,
            isp: nil,
            reverseDNS: nil,
            rdapOrganisation: nil,
            countryRegion: nil,
            torExitNode: nil,
            datacentreHint: nil,
            lastChecked: Date(),
            fromCache: false
        )
    }

    private func buildReport(ip: String, kind: IPAddressKind, reverseDNS: String?, dnsblListings: [DNSBLListing], providerResults: [IPSafetyProviderResult]) -> IPSafetyReport {
        let listedCount = dnsblListings.filter(\.listed).count
        let torListed = providerResults.first(where: { $0.provider == "Tor Exit Nodes" })?.status == "Listed"
        let abuseHigh = providerResults.first(where: { $0.provider == "AbuseIPDB" })?.status.split(separator: "%").first.flatMap { Int($0) }.map { $0 >= 50 } ?? false
        let vtMalicious = providerResults.first(where: { $0.provider == "VirusTotal" })?.status.split(separator: " ").first.flatMap { Int($0) }.map { $0 > 0 } ?? false
        let greyNoiseBad = (providerResults.first(where: { $0.provider == "GreyNoise" })?.status.lowercased()).map { $0.contains("malicious") || $0.contains("noise") } ?? false
        let rdapResult = providerResults.first { $0.provider == "RDAP" }
        let asnResult = providerResults.first { $0.provider == "Team Cymru ASN" }
        let hostingHint = hostingProviderHint(from: [rdapResult?.detail, asnResult?.detail, reverseDNS].compactMap { $0 }.joined(separator: " "))

        var score = 0
        if torListed { score += 35 }
        if listedCount == 1 { score += 25 } else if listedCount > 1 { score += 45 }
        if abuseHigh { score += 40 }
        if vtMalicious { score += 40 }
        if greyNoiseBad { score += 30 }
        if hostingHint != nil { score += 10 }
        score = min(100, score)

        var facts: [String] = []
        if listedCount > 0 { facts.append("appears on \(listedCount) DNSBL list\(listedCount == 1 ? "" : "s")") }
        if torListed { facts.append("is a Tor exit node") }
        if abuseHigh { facts.append("has high AbuseIPDB confidence") }
        if vtMalicious { facts.append("has VirusTotal malicious detections") }
        if greyNoiseBad { facts.append("is flagged by GreyNoise") }
        let summary = facts.isEmpty
            ? "No enabled free provider flagged this IP. Review context before blocking."
            : "This IP \(facts.joined(separator: " and ")). Treat with caution. Review before blocking."

        return IPSafetyReport(
            ip: ip,
            addressKind: kind,
            riskScore: score,
            riskLabel: IPSafetyRiskLabel.label(for: score),
            summary: summary,
            providerResults: providerResults,
            dnsblListings: dnsblListings,
            asn: asnResult?.detail,
            isp: asnResult?.detail,
            reverseDNS: reverseDNS,
            rdapOrganisation: rdapResult?.detail,
            countryRegion: rdapResult?.detail,
            torExitNode: torListed,
            datacentreHint: hostingHint,
            lastChecked: Date(),
            fromCache: false
        )
    }

    private func reverseDNS(ip: String) async -> String? {
        guard let reversed = IPSafetyAddressClassifier.reversedIPv4(ip) else { return nil }
        let output = try? await DNSBLClient.run(executable: "/usr/bin/dig", arguments: ["+short", "PTR", "\(reversed).in-addr.arpa"])
        return output?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private nonisolated func skipped(_ provider: String) -> IPSafetyProviderResult {
        IPSafetyProviderResult(provider: provider, status: "Disabled", detail: "Provider disabled in Settings.")
    }

    private func hostingProviderHint(from text: String) -> String? {
        let lower = text.lowercased()
        let hints = ["amazon", "aws", "google cloud", "microsoft", "azure", "digitalocean", "linode", "ovh", "hetzner", "cloudflare", "hosting", "datacenter", "data center"]
        return hints.first(where: { lower.contains($0) })
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
