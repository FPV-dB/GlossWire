import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func enrichmentStoreHonoursExpiryAndReplacement() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json"); defer { try? FileManager.default.removeItem(at: url) }
    let store = EndpointEnrichmentStore(url: url), now = Date(timeIntervalSince1970: 1000)
    let expired = EndpointEnrichmentRecord(address: "1.1.1.1", reverseDNS: "old", asn: nil, rdap: nil, riskScore: 0, riskLabel: "Low", checkedAt: now, expiresAt: now)
    try await store.save(expired); #expect(await store.record(for: "1.1.1.1", now: now.addingTimeInterval(1)) == nil)
    let fresh = EndpointEnrichmentRecord(address: "1.1.1.1", reverseDNS: "one.one.one.one", asn: "AS13335", rdap: "Cloudflare", riskScore: 0, riskLabel: "Low", checkedAt: now, expiresAt: now.addingTimeInterval(100))
    try await store.save(fresh); #expect(await store.load().count == 1); #expect(await store.record(for: "1.1.1.1", now: now)?.reverseDNS == "one.one.one.one")
}

@Test func tlsParserExtractsCertificateAndHandshakeSummary() {
    let certificate = "subject=CN=example.com\nissuer=CN=Test CA\nnotBefore=Jul 1 00:00:00 2026 GMT\nnotAfter=Jul 1 00:00:00 2027 GMT\nsha256 Fingerprint=AA:BB\n"
    let handshake = "    Protocol  : TLSv1.3\n    Cipher    : TLS_AES_256_GCM_SHA384\n"
    let result = EndpointEnrichmentService.parseTLS(host: "example.com", port: 443, certificateText: certificate, handshakeText: handshake)
    #expect(result.subject == "CN=example.com"); #expect(result.issuer == "CN=Test CA"); #expect(result.protocolVersion == "TLSv1.3"); #expect(result.cipher == "TLS_AES_256_GCM_SHA384")
    #expect(EndpointEnrichmentService.firstCertificate("x\n-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----\ny")?.contains("abc") == true)
}
