import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func processHierarchyAndFlowEdgesUseVisibleEvidence() throws {
    let processes = ProcessHierarchyService.parse("  10  1 /Applications/Browser.app/Contents/MacOS/Browser\n  11 10 /usr/bin/helper\n")
    #expect(processes.map(\.pid) == [10, 11]); #expect(processes[1].parentPID == 10)
    let record = AppConnectionRecord(id: "1", timestamp: Date(), appBundleIdentifier: "Browser", pid: 11, direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "1", remoteAddress: "1.1.1.1", remotePort: "443", remoteHostname: "example.com", countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    let analyzer = InvestigationVisualAnalyzer(), node = try #require(analyzer.processNodes(processes: processes, records: [record]).first)
    #expect(node.depth == 1); #expect(node.connectionCount == 1)
    let edge = try #require(analyzer.flowEdges(records: [record]).first); #expect(edge.process == "Browser"); #expect(edge.destination == "example.com"); #expect(edge.count == 1)
}
