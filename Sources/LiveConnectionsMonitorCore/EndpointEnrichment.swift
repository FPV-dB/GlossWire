import Foundation

public struct TLSEndpointSummary: Codable, Hashable, Sendable {
    public let host: String; public let port: Int; public let subject: String?; public let issuer: String?; public let notBefore: String?; public let notAfter: String?
    public let sha256Fingerprint: String?; public let protocolVersion: String?; public let cipher: String?; public let checkedAt: Date
}
public struct EndpointEnrichmentRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String { address }; public let address: String; public let reverseDNS: String?; public let asn: String?; public let rdap: String?
    public let riskScore: Int; public let riskLabel: String; public let checkedAt: Date; public let expiresAt: Date
}

public actor EndpointEnrichmentStore {
    private let url: URL
    public init(url: URL? = nil) { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.url = url ?? base.appendingPathComponent("Live Connections Monitor/endpoint-enrichment.json") }
    public func load(includeExpired: Bool = true, now: Date = Date()) -> [EndpointEnrichmentRecord] { guard let data = try? Data(contentsOf: url) else { return [] }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; let values = (try? decoder.decode([EndpointEnrichmentRecord].self, from: data)) ?? []; return includeExpired ? values : values.filter { $0.expiresAt > now } }
    public func record(for address: String, now: Date = Date()) -> EndpointEnrichmentRecord? { load(includeExpired: false, now: now).first { $0.address == address } }
    public func save(_ record: EndpointEnrichmentRecord) throws { guard !GlossWireLogPolicy.isDisabled else { return }; var values = load().filter { $0.address != record.address }; values.insert(record, at: 0); if values.count > 2_000 { values.removeLast(values.count - 2_000) }; let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try encoder.encode(values).write(to: url, options: .atomic) }
}

public actor EndpointEnrichmentService {
    private let safety = IPSafetyService(); private let store: EndpointEnrichmentStore
    public init(store: EndpointEnrichmentStore = EndpointEnrichmentStore()) { self.store = store }
    public func enrich(address: String, refresh: Bool = false, ttl: TimeInterval = 86_400) async -> EndpointEnrichmentRecord {
        let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !refresh, let cached = await store.record(for: clean) { return cached }
        let report = await safety.check(ip: clean, settings: IPSafetyProviderSettings(), refresh: refresh)
        let record = EndpointEnrichmentRecord(address: clean, reverseDNS: report.reverseDNS, asn: report.asn, rdap: report.rdapOrganisation,
            riskScore: report.riskScore, riskLabel: report.riskLabel.rawValue, checkedAt: Date(), expiresAt: Date().addingTimeInterval(ttl))
        try? await store.save(record); return record
    }
    public func inspectTLS(host: String, port: Int) async throws -> TLSEndpointSummary {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, (1...65_535).contains(port) else { throw CommandRunnerError.launchFailed("A valid TLS host and port are required.") }
        let handshake = try await CommandRunner().run("/usr/bin/openssl", arguments: ["s_client", "-connect", "\(clean):\(port)", "-servername", clean, "-showcerts"], standardInput: Data())
        let combined = handshake.output + "\n" + handshake.errorOutput
        guard let certificate = Self.firstCertificate(combined) else { throw CommandRunnerError.failed(path: "/usr/bin/openssl", code: handshake.exitCode, output: "No peer certificate was returned.") }
        let x509 = try await CommandRunner().run("/usr/bin/openssl", arguments: ["x509", "-noout", "-subject", "-issuer", "-dates", "-fingerprint", "-sha256"], standardInput: Data(certificate.utf8))
        return Self.parseTLS(host: clean, port: port, certificateText: x509.output, handshakeText: combined)
    }
    public static func firstCertificate(_ text: String) -> String? { guard let start = text.range(of: "-----BEGIN CERTIFICATE-----"), let end = text.range(of: "-----END CERTIFICATE-----", range: start.lowerBound..<text.endIndex) else { return nil }; return String(text[start.lowerBound..<end.upperBound]) + "\n" }
    public static func parseTLS(host: String, port: Int, certificateText: String, handshakeText: String, now: Date = Date()) -> TLSEndpointSummary {
        func value(_ prefix: String) -> String? { certificateText.split(whereSeparator: \.isNewline).map(String.init).first { $0.lowercased().hasPrefix(prefix.lowercased()) }?.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } }
        let protocolVersion = handshakeText.split(whereSeparator: \.isNewline).map(String.init).first { $0.contains("Protocol  :") }?.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) }
        let cipher = handshakeText.split(whereSeparator: \.isNewline).map(String.init).first { $0.contains("Cipher    :") }?.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) }
        return TLSEndpointSummary(host: host, port: port, subject: value("subject="), issuer: value("issuer="), notBefore: value("notBefore="), notAfter: value("notAfter="), sha256Fingerprint: value("sha256 Fingerprint="), protocolVersion: protocolVersion, cipher: cipher, checkedAt: now)
    }
}

@MainActor public final class EndpointEnrichmentViewModel: ObservableObject {
    @Published public var address = ""; @Published public var tlsHost = ""; @Published public var tlsPort = "443"; @Published public private(set) var records: [EndpointEnrichmentRecord] = []; @Published public private(set) var tls: TLSEndpointSummary?; @Published public private(set) var working = false; @Published public var error: String?
    private let service: EndpointEnrichmentService; private let store: EndpointEnrichmentStore
    public init(service: EndpointEnrichmentService = EndpointEnrichmentService(), store: EndpointEnrichmentStore = EndpointEnrichmentStore()) { self.service = service; self.store = store }
    public func load() async { records = await store.load() }
    public func enrich(refresh: Bool = false) async { guard !working else { return }; working = true; let result = await service.enrich(address: address, refresh: refresh); records = [result] + records.filter { $0.address != result.address }; working = false }
    public func inspectTLS() async { guard !working else { return }; working = true; do { tls = try await service.inspectTLS(host: tlsHost, port: Int(tlsPort) ?? 443) } catch { self.error = error.localizedDescription }; working = false }
}
