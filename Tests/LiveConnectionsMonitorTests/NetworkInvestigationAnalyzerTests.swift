import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

private func investigationRecord(_ id: String, time: TimeInterval, app: String, remote: String, port: String) -> AppConnectionRecord {
    AppConnectionRecord(id: id, timestamp: Date(timeIntervalSince1970: time), appBundleIdentifier: app, pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "192.168.1.2", localPort: "50000", remoteAddress: remote, remotePort: port, remoteHostname: nil, countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 2, ruleAction: .observed)
}

@Test func whatChangedComparesAdjacentWindows() {
    let records = [
        investigationRecord("old", time: 1_000, app: "Steam", remote: "198.51.100.1", port: "443"),
        investigationRecord("new", time: 4_000, app: "Discord", remote: "203.0.113.2", port: "3478")
    ]
    let summary = NetworkInvestigationAnalyzer().changes(records: records, now: Date(timeIntervalSince1970: 4_600), interval: 3_000)
    #expect(summary.newProcesses == ["Discord"])
    #expect(summary.disconnectedProcesses == ["Steam"])
    #expect(summary.newPorts == ["3478"])
}

@Test func topologyIncludesOnlyObservedPrivateDestinations() {
    let records = [
        investigationRecord("lan", time: 2_000, app: "Finder", remote: "192.168.1.20", port: "445"),
        investigationRecord("wan", time: 2_100, app: "Safari", remote: "203.0.113.20", port: "443")
    ]
    let nodes = NetworkInvestigationAnalyzer().topology(records: records)
    #expect(nodes.count == 1)
    #expect(nodes[0].address == "192.168.1.20")
    #expect(nodes[0].name.contains("NAS"))
}
