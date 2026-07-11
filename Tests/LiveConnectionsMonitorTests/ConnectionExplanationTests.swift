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
