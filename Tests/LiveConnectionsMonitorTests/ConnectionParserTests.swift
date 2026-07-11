import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func parsesEstablishedLsofTCPConnection() {
    let sample = """
    COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    Safari     123 me     12u  IPv4 0xabc              0t0  TCP 192.168.1.10:52144->93.184.216.34:443 (ESTABLISHED)
    """
    let connections = ConnectionParser().parseLsof(sample, now: Date(timeIntervalSince1970: 1))
    #expect(connections.count == 1)
    #expect(connections[0].processName == "Safari")
    #expect(connections[0].pid == 123)
    #expect(connections[0].protocolKind == .tcp)
    #expect(connections[0].direction == .established)
    #expect(connections[0].local.address == "192.168.1.10")
    #expect(connections[0].local.port == "52144")
    #expect(connections[0].remote?.address == "93.184.216.34")
    #expect(connections[0].remote?.port == "443")
}

@Test func parsesListeningLsofTCPConnection() {
    let sample = """
    COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    sshd       456 root    5u  IPv6 0xabc              0t0  TCP *:22 (LISTEN)
    """
    let connection = ConnectionParser().parseLsof(sample).first
    #expect(connection?.direction == .listening)
    #expect(connection?.remote == nil)
    #expect(connection?.local.port == "22")
}

@Test func parsesNetstatFallbackLine() {
    let sample = "tcp4       0      0  192.168.1.10.52144   93.184.216.34.443    ESTABLISHED"
    let connection = ConnectionParser().parseNetstat(sample).first
    #expect(connection?.protocolKind == .tcp)
    #expect(connection?.state == "ESTABLISHED")
}

@Test func validatorRefusesUnsafeAddressesAndWarnsForPrivateLAN() {
    let validator = IPAddressValidator()
    if case .refused = validator.validate("127.0.0.1") {} else {
        Issue.record("Expected loopback to be refused")
    }
    if case .refused = validator.validate("224.0.0.1") {} else {
        Issue.record("Expected multicast to be refused")
    }
    if case .warning = validator.validate("192.168.1.0/24") {} else {
        Issue.record("Expected private LAN range warning")
    }
    if case .valid = validator.validate("93.184.216.34") {} else {
        Issue.record("Expected public IPv4 to be valid")
    }
}

@Test func blocklistParserDeduplicatesAndSkipsInvalidLines() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
    try """
    # comment
    93.184.216.34
    93.184.216.34
    192.168.1.0/24
    not-an-ip
    ; another comment
    """.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    let parsed = try BlocklistImportService().parse(url: url)
    #expect(parsed.entries.map(\.value) == ["192.168.1.0/24", "93.184.216.34"])
    #expect(parsed.skipped == 1)
    #expect(parsed.warnings.count == 1)
}

@Test func geoSimulationMatchesIPv4CIDR() {
    let countries = [
        GeoBlockCountry(countryCode: "ZZ", countryName: "Testland", ipv4RangeCount: 1, ipv6RangeCount: 0, isEnabled: true, direction: .both, lastImportedAt: Date(), sourceName: "test", notes: "", expiresAt: nil)
    ]
    let ranges = [
        GeoBlockRange(id: 1, countryCode: "ZZ", countryName: "Testland", cidr: "93.184.216.0/24", ipVersion: .ipv4, sourceName: "test", importedAt: Date(), isEnabled: true, validationStatus: "valid")
    ]
    let connections = [
        NetworkConnection(processName: "Safari", pid: 12, protocolKind: .tcp, direction: .established, local: NetworkEndpoint(address: "192.168.1.2", port: "50000"), remote: NetworkEndpoint(address: "93.184.216.34", port: "443"), state: "ESTABLISHED", firstSeen: Date(), lastSeen: Date())
    ]
    let simulation = GeoBlockSimulationService().simulate(countries: countries, ranges: ranges, connections: connections, allowlist: [])
    #expect(simulation.affectedConnections.count == 1)
    #expect(simulation.generatedRuleCount == 2)
}

@Test func lookupServiceRefusesReservedAddresses() {
    let service = LookupService()
    if case .failure(.reservedAddress) = service.canLookup(ip: "192.168.1.1") {} else {
        Issue.record("Expected private IP lookup to be refused")
    }
    if case .success("93.184.216.34") = service.canLookup(ip: "93.184.216.34") {} else {
        Issue.record("Expected public IP lookup to be allowed")
    }
}

@Test func parsesOfficialGoogleIPRangeDocuments() throws {
    let data = Data("""
    {"syncToken":"1","prefixes":[
      {"ipv4Prefix":"8.8.8.0/24"},
      {"ipv6Prefix":"2001:4860::/32"},
      {"service":"ignored"}
    ]}
    """.utf8)
    let ranges = try GoogleIPRangeService().parse(data: data)
    #expect(ranges == ["8.8.8.0/24", "2001:4860::/32"])
}

@Test func parsesIPReputationFeedLines() {
    let subscription = BlockListSubscription(
        id: "test-ip-feed",
        name: "Test IP Feed",
        category: .malwareSecurity,
        url: URL(string: "https://example.com/feed.txt")!,
        description: "test",
        isEnabledByDefault: false,
        localCachePath: "test.txt",
        listType: .ipList
    )
    let rules = BlockListParser().parse("""
    # comment
    203.0.113.4
    198.51.100.0/24 ; listed range
    10.0.0.999
    bad.example
    2001:db8::/32
    """, subscription: subscription)

    #expect(rules.map(\.value) == ["203.0.113.4", "198.51.100.0/24", "2001:db8::/32"])
}

@Test func publicIPReputationCatalogIncludesOptionalFeeds() {
    let ids = Set(ReputationBlockListCatalog.subscriptions.map(\.id))
    #expect(ids.isSuperset(of: [
        "spamhaus-drop",
        "dshield",
        "feodo-tracker",
        "firehol-ipsum-3",
        "firehol-ipsum-4",
        "cins-army",
        "binary-defense-artillery"
    ]))
    #expect(ReputationBlockListCatalog.subscriptions.first { $0.id == "spamhaus-drop" }?.isEnabledByDefault == false)
}

@MainActor
@Test func blockListStoreCanEnableAllLists() {
    let suiteName = "LiveConnectionsMonitorTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ReputationBlockListStore(defaults: defaults)

    store.resetRecommendedDefaults()
    #expect(store.enabledIDs.count < ReputationBlockListCatalog.subscriptions.count)

    store.enableAllLists()
    #expect(store.enabledIDs == Set(ReputationBlockListCatalog.subscriptions.map(\.id)))
}

@Test func parsesMicrosoftServiceTagDocuments() throws {
    let data = Data("""
    {"changeNumber":1,"values":[
      {"name":"AzureCloud","properties":{"addressPrefixes":["13.64.0.0/11","2603:1000::/24"]}},
      {"name":"Ignored","properties":{"addressPrefixes":[]}}
    ]}
    """.utf8)
    let ranges = try MicrosoftIPRangeService().parse(data: data)
    #expect(ranges == ["13.64.0.0/11", "2603:1000::/24"])
}

@Test func extractsMicrosoftServiceTagManifestURL() throws {
    let data = Data("""
    <a href="https://download.microsoft.com/download/7/1/d/71d86715-5596-4529-9b13-da13a5de5b63/ServiceTags_Public_20260706.json">Download</a>
    """.utf8)
    let url = MicrosoftIPRangeService.extractManifestURL(from: data)
    #expect(url?.absoluteString.hasSuffix("ServiceTags_Public_20260706.json") == true)
}

@Test func managedGoogleBlocklistRefreshReplacesEntries() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let database = try FirewallDatabase(url: url)

    try database.replaceManagedBlocklist(
        name: GoogleIPRangeService.managedBlocklistName,
        sourceFilename: "first",
        notes: "test",
        entries: ["8.8.8.0/24", "2001:4860::/32"],
        enabled: true
    )
    try database.replaceManagedBlocklist(
        name: GoogleIPRangeService.managedBlocklistName,
        sourceFilename: "second",
        notes: "test",
        entries: ["8.8.4.0/24"],
        enabled: true
    )

    #expect(try database.blocklists().filter { $0.name == GoogleIPRangeService.managedBlocklistName }.count == 1)
    #expect(try database.entries().map(\.value) == ["8.8.4.0/24"])
}

@Test func firewallSettingsPersistMicrosoftBlockingState() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let database = try FirewallDatabase(url: url)
    let timestamp = Date(timeIntervalSince1970: 1234)

    var settings = FirewallSettings()
    settings.blockKnownMicrosoftConnections = true
    settings.microsoftRangesLastUpdatedAt = timestamp
    try database.save(settings: settings)

    let reloaded = try database.settings()
    #expect(reloaded.blockKnownMicrosoftConnections)
    #expect(reloaded.microsoftRangesLastUpdatedAt == timestamp)
}

@Test func firewallSettingsPersistBlockedNetworkServices() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let database = try FirewallDatabase(url: url)
    var settings = FirewallSettings()
    settings.blockedServiceIDs = [NetworkServiceBlockPreset.vnc.id, NetworkServiceBlockPreset.smb.id]

    try database.save(settings: settings)

    #expect(try database.settings().blockedServiceIDs == settings.blockedServiceIDs)
}
