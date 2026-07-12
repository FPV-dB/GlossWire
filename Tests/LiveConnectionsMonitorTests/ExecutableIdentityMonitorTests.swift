import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func executableIdentityDetectsHashAndSignerChanges() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    try Data("new executable".utf8).write(to: file)
    let app = RunningAppNetworkSummary(id: "com.example.helper", appName: "Helper", bundleIdentifier: "com.example.helper", pid: 1,
        executablePath: file.path, teamIdentifier: "NEWTEAM", currentUploadBps: 0, currentDownloadBps: 0, totalUploadedBytes: 0,
        totalDownloadedBytes: 0, activeConnectionCount: 0, lastSeen: nil, isRunning: true)
    let old = ExecutableIdentity(id: "com.example.helper", appName: "Helper", path: file.path, sha256: "oldhash", teamIdentifier: "OLDTEAM", observedAt: .distantPast)
    let result = await ExecutableIdentityService().scan(apps: [app], previous: [old.id: old])
    let change = try #require(result.1.first)
    #expect(change.oldHash == "oldhash")
    #expect(change.newHash.count == 64)
    #expect(change.severity.contains("signer changed"))
}
