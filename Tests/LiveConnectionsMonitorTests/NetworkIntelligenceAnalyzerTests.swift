import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

private func intelRecord(_ id: String, day: TimeInterval, app: String, remote: String, port: String, host: String? = nil, bytes: UInt64? = nil) -> AppConnectionRecord {
    AppConnectionRecord(id: id, timestamp: Date(timeIntervalSince1970: day), appBundleIdentifier: app, pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "192.168.1.2", localPort: "50000", remoteAddress: remote, remotePort: port, remoteHostname: host, countryCode: "AU", state: "ESTABLISHED", bytesSent: bytes, bytesReceived: bytes, duration: 10, ruleAction: .observed)
}

@Test func periodicAndIPv6SignalsAreEvidenceBasedAndCapabilitiesAreGated() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let records = (0..<5).map { index in
        AppConnectionRecord(id: "b\(index)", timestamp: start.addingTimeInterval(Double(index * 60)), appBundleIdentifier: "helper", pid: 7,
                            direction: .outbound, protocolKind: .tcp, localAddress: "::1", localPort: "5000",
                            remoteAddress: "2001:db8::8", remotePort: "443", remoteHostname: nil, countryCode: nil,
                            state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    }
    let analyzer = NetworkIntelligenceAnalyzer()
    let signals = analyzer.behaviourSignals(records: records)
    #expect(signals.contains { $0.kind == .beacon && $0.process == "helper" })
    #expect(signals.contains { $0.kind == .ipv6 && $0.process == "helper" })
    let coverage = analyzer.detectionCapabilities(provider: .processCounters)
    #expect(coverage.first { $0.id == "Process upload spike detection" }?.available == true)
    #expect(coverage.first { $0.id == "Per-flow upload attribution" }?.available == false)
    #expect(coverage.first { $0.id == "Inbound port-scan detection" }?.available == false)
}

@Test func uploadSpikeForecastAndServiceRecognitionUseSupportedEvidence() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let samples = (0..<4).map { AppTrafficSample(timestamp: now.addingTimeInterval(Double($0 - 4)), appBundleIdentifier: "sync", uploadBps: 100_000, downloadBps: 0, activeConnectionCount: 1) }
        + [AppTrafficSample(timestamp: now, appBundleIdentifier: "sync", uploadBps: 4_000_000, downloadBps: 0, activeConnectionCount: 1)]
    let record = AppConnectionRecord(id: "plex", timestamp: now, appBundleIdentifier: "Plex", pid: 1, direction: .outbound, protocolKind: .tcp,
        localAddress: "127.0.0.1", localPort: "1", remoteAddress: "192.168.1.2", remotePort: "32400", remoteHostname: "plex.local",
        countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    let analyzer = NetworkIntelligenceAnalyzer()
    let spike = analyzer.uploadSpikes(samplesByApp: ["sync": samples]).first
    #expect(spike?.currentBps == 4_000_000)
    #expect(spike?.multiplier == 40)
    #expect(analyzer.recognizedServices(records: [record]).first?.id == "Plex")
    #expect(analyzer.activityForecast(records: [record], now: now).todayObservations == 1)
}

@Test func ratingsFingerprintAndLocalExplanationUseRetainedEvidence() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let records = (0..<6).map { index in
        AppConnectionRecord(id: "r\(index)", timestamp: now.addingTimeInterval(Double(index - 5) * 10), appBundleIdentifier: "browser", pid: 1,
                            direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "1",
                            remoteAddress: "1.1.1.\(index % 2)", remotePort: "443", remoteHostname: nil, countryCode: "AU", state: "ESTABLISHED",
                            bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    }
    let analyzer = NetworkIntelligenceAnalyzer()
    let rating = analyzer.internetRatings(records: records).first
    #expect(rating?.encryptedPercent == 100)
    #expect(rating?.destinationEntropy ?? 0 > 0)
    #expect(analyzer.explainMyComputer(records: records, now: now).contains("browser"))
    #expect(analyzer.fingerprint(records: records, now: now).currentSignature.count == 16)
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
