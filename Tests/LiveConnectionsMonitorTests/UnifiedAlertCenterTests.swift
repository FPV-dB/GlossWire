import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func alertStoreDeduplicatesTracksStatusAndHonoursMute() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = UnifiedAlertStore(directory: directory); let now = Date(timeIntervalSince1970: 1_700_000_000)
    try await store.record(severity: .warning, category: "Test", title: "Spike", detail: "One", process: "sync", key: "spike:sync", now: now)
    try await store.record(severity: .warning, category: "Test", title: "Spike", detail: "Two", process: "sync", key: "spike:sync", now: now.addingTimeInterval(30))
    var alerts = await store.load(); #expect(alerts.count == 1); #expect(alerts[0].occurrenceCount == 2)
    try await store.setStatus(id: alerts[0].id, status: .acknowledged); alerts = await store.load(); #expect(alerts[0].status == .acknowledged)
    try await store.mute(process: "sync"); try await store.record(severity: .critical, category: "Test", title: "Again", detail: "Muted", process: "sync", key: "other", now: Date())
    #expect(await store.load().count == 1)
}

@Test func alertEvaluatorCreatesNewProcessAndDestinationAlerts() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true); defer { try? FileManager.default.removeItem(at: directory) }
    let store = UnifiedAlertStore(directory: directory), now = Date()
    let old = AppConnectionRecord(id: "old", timestamp: now.addingTimeInterval(-7200), appBundleIdentifier: "known", pid: 1, direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "1", remoteAddress: "1.1.1.1", remotePort: "443", remoteHostname: nil, countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    let fresh = AppConnectionRecord(id: "new", timestamp: now, appBundleIdentifier: "new.app", pid: 2, direction: .outbound, protocolKind: .tcp, localAddress: "127.0.0.1", localPort: "2", remoteAddress: "8.8.8.8", remotePort: "443", remoteHostname: nil, countryCode: nil, state: "ESTABLISHED", bytesSent: nil, bytesReceived: nil, duration: 0, ruleAction: .observed)
    try await UnifiedAlertEvaluator().evaluate(records: [old, fresh], samples: [:], store: store, now: now)
    let categories = Set(await store.load().map(\.category)); #expect(categories.contains("New process")); #expect(categories.contains("New destination"))
}
