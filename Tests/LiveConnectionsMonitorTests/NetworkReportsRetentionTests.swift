import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func dailyReportSummarisesPeriodAndNewProcesses() {
    let calendar = Calendar(identifier: .gregorian), day = Date(timeIntervalSince1970: 1_700_000_000), start = calendar.startOfDay(for: day)
    func record(_ id: String, _ date: Date, _ app: String) -> AppConnectionRecord { AppConnectionRecord(id: id, timestamp: date, appBundleIdentifier: app, pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "1", remoteAddress: "1.1.1.1", remotePort: "443", remoteHostname: nil, countryCode: "AU", state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed) }
    let report = LocalNetworkReportGenerator().daily(records: [record("old", start.addingTimeInterval(-10), "known"), record("new", start.addingTimeInterval(10), "new.app")], day: day)
    #expect(report.observations == 1); #expect(report.processes == 1); #expect(report.newProcesses == ["new.app"])
}

@Test func applicationHistoryPrunesByAgeAndCompacts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true); defer { try? FileManager.default.removeItem(at: directory) }
    let database = try ApplicationNetworkDatabase(url: directory.appendingPathComponent("applications.sqlite")), now = Date()
    func record(_ id: String, _ date: Date) -> AppConnectionRecord { AppConnectionRecord(id: id, timestamp: date, appBundleIdentifier: "app", pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "1", remoteAddress: "1.1.1.1", remotePort: "443", remoteHostname: nil, countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed) }
    try database.save([record("old", now.addingTimeInterval(-1000)), record("new", now)], historyLimit: 100)
    #expect(try database.pruneHistory(olderThan: now.addingTimeInterval(-100)) == 1); try database.compact(); #expect(try database.historyCount() == 1)
}
