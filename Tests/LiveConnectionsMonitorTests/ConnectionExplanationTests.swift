import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func explanationIdentifiesHTTPSAndBrowserContextWithoutClaimingPayloadKnowledge() {
    let connection = NetworkConnection(
        processName: "Google Chrome", pid: 42, protocolKind: .tcp, direction: .established,
        local: NetworkEndpoint(address: "192.0.2.10", port: "51000"),
        remote: NetworkEndpoint(address: "198.51.100.20", port: "443"),
        state: "ESTABLISHED", firstSeen: Date(), lastSeen: Date()
    )

    let explanation = ConnectionExplanationService().explain(connection)

    #expect(explanation.headline.contains("HTTPS"))
    #expect(explanation.explanation.contains("web browser"))
    #expect(explanation.explanation.contains("cannot be proven"))
    #expect(explanation.evidence.contains { $0.contains("Port 443") })
}

@Test func explanationDescribesMDNSPort() {
    let connection = NetworkConnection(
        processName: "mDNSResponder", pid: 1, protocolKind: .udp, direction: .outgoing,
        local: NetworkEndpoint(address: "0.0.0.0", port: "5353"),
        remote: NetworkEndpoint(address: "224.0.0.251", port: "5353"),
        state: "", firstSeen: Date(), lastSeen: Date()
    )

    let explanation = ConnectionExplanationService().explain(connection)
    #expect(explanation.headline.contains("mDNS"))
    #expect(explanation.evidence.contains { $0.contains("Bonjour") })
}

@Test func commonServiceLookupExplainsUnknownAndKnownPorts() {
    #expect(ConnectionExplanationService.serviceName(for: "5353").contains("Bonjour"))
    #expect(ConnectionExplanationService.serviceName(for: "65000") == "Port 65000")
}

@Test func privacyRedactorMasksAddressesHostnamesProcessesAndPaths() {
    #expect(PrivacyRedactor.address("203.0.113.42", enabled: true) == "203.0.x.x")
    #expect(PrivacyRedactor.hostname("api.example.com", enabled: true) == "hidden.example")
    #expect(PrivacyRedactor.process("com.example.Secret", enabled: true) == "Application")
    #expect(PrivacyRedactor.path("/Users/name/App", enabled: true) == "~/…/Application")
    #expect(PrivacyRedactor.address("203.0.113.42", enabled: false) == "203.0.113.42")
}
