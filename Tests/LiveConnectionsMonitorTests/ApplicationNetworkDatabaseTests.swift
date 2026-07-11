import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func applicationHistoryPersistsTrimsAndClears() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try ApplicationNetworkDatabase(url: directory.appendingPathComponent("applications.sqlite"))
    let base = Date(timeIntervalSince1970: 1_000)
    let records = (0..<3).map { offset in
        AppConnectionRecord(
            id: "record-\(offset)", timestamp: base.addingTimeInterval(Double(offset)),
            appBundleIdentifier: "com.example.App", pid: 42, direction: .outbound,
            protocolKind: .tcp, localAddress: "192.0.2.1", localPort: "5000",
            remoteAddress: "198.51.100.\(offset)", remotePort: "443", remoteHostname: nil,
            countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil,
            duration: Double(offset), ruleAction: .allowed
        )
    }

    try database.save(records, historyLimit: 2)
    let saved = try database.recentConnections(for: "com.example.App", limit: 10)
    #expect(saved.map(\.id) == ["record-2", "record-1"])
    #expect(saved.first?.remotePort == "443")

    try database.clearHistory(for: "com.example.App")
    #expect(try database.recentConnections(for: "com.example.App", limit: 10).isEmpty)
}

@Test func applicationRulesPersist() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("applications.sqlite")
    do {
        let database = try ApplicationNetworkDatabase(url: url)
        try database.setRule(.manualBlock, for: "com.example.App")
    }
    let reopened = try ApplicationNetworkDatabase(url: url)
    #expect(try reopened.rules()["com.example.App"] == .manualBlock)
}

@Test func globalTimelineQueriesAcrossApplicationsAndRespectsTimeWindow() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try ApplicationNetworkDatabase(url: directory.appendingPathComponent("applications.sqlite"))
    let records = [
        AppConnectionRecord(id: "old", timestamp: Date(timeIntervalSince1970: 1_000), appBundleIdentifier: "app.one", pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "192.0.2.1", localPort: "50000", remoteAddress: "198.51.100.1", remotePort: "443", remoteHostname: nil, countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 1, ruleAction: .observed),
        AppConnectionRecord(id: "new", timestamp: Date(timeIntervalSince1970: 2_000), appBundleIdentifier: "app.two", pid: 2, direction: .outbound, protocolKind: .udp, localAddress: "192.0.2.1", localPort: "50001", remoteAddress: "203.0.113.2", remotePort: "53", remoteHostname: nil, countryCode: nil, state: "", bytesSent: nil, bytesReceived: nil, duration: 1, ruleAction: .observed)
    ]
    try database.save(records, historyLimit: 10)

    #expect(try database.recentConnections(limit: 10).map(\.id) == ["new", "old"])
    #expect(try database.recentConnections(limit: 10, since: Date(timeIntervalSince1970: 1_500)).map(\.id) == ["new"])
}
