import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

private func intelRecord(_ id: String, day: TimeInterval, app: String, remote: String, port: String, host: String? = nil, bytes: UInt64? = nil) -> AppConnectionRecord {
    AppConnectionRecord(id: id, timestamp: Date(timeIntervalSince1970: day), appBundleIdentifier: app, pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "192.168.1.2", localPort: "50000", remoteAddress: remote, remotePort: port, remoteHostname: host, countryCode: "AU", state: "ESTABLISHED", bytesSent: bytes, bytesReceived: bytes, duration: 10, ruleAction: .observed)
}

@Test func passportsAndNetworkMemoryAggregateRetainedContext() {
    let records = [
        intelRecord("1", day: 1_000, app: "Safari", remote: "203.0.113.1", port: "443", host: "api.example.com"),
        intelRecord("2", day: 90_000, app: "Safari", remote: "203.0.113.1", port: "443", host: "cdn.example.com")
    ]
    let analyzer = NetworkIntelligenceAnalyzer()
    let passport = try! #require(analyzer.passports(records: records).first)
    #expect(passport.id == "Safari")
    #expect(passport.daysSeen == 2)
    #expect(passport.typicalPorts == ["443"])
    let memory = try! #require(analyzer.networkMemory(records: records).first)
    #expect(memory.daysSeen == 2)
    #expect(memory.processes == ["Safari"])
}

@Test func portDomainCalendarAndJournalSummariesAreLocalAndAccurate() {
    let now = Date()
    let record = intelRecord("1", day: now.timeIntervalSince1970, app: "Safari", remote: "203.0.113.1", port: "443", host: "api.example.com", bytes: 100)
    let analyzer = NetworkIntelligenceAnalyzer()
    #expect(analyzer.ports(records: [record]).first?.service.contains("HTTPS") == true)
    #expect(analyzer.domainFamilies(records: [record]).first?.id == "example.com")
    #expect(analyzer.calendarActivity(records: [record]).first?.observations == 1)
    let journal = analyzer.journal(records: [record], day: now)
    #expect(journal.contains("Safari"))
    #expect(journal.contains("endpoint metadata"))
}
