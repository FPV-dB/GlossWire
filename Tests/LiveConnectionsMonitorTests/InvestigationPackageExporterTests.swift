import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func investigationPackageCreatesAuditableZipContents() async throws {
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
    let expanded = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: destination); try? FileManager.default.removeItem(at: expanded) }
    try await InvestigationPackageExporter().export(to: destination, records: [], weather: [], bookmarks: [], privacyMode: true)
    #expect(FileManager.default.fileExists(atPath: destination.path))
    try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)
    let result = try await CommandRunner().run("/usr/bin/ditto", arguments: ["-x", "-k", destination.path, expanded.path])
    #expect(result.exitCode == 0)
    let package = try #require((try FileManager.default.contentsOfDirectory(at: expanded, includingPropertiesForKeys: nil)).first)
    let names = Set(try FileManager.default.contentsOfDirectory(atPath: package.path))
    #expect(names.contains("README.txt"))
    #expect(names.contains("CAPABILITIES.txt"))
    #expect(names.contains("connections.csv"))
    #expect(names.contains("connections.json"))
    #expect(names.contains("internet-weather.json"))
    #expect(names.contains("timeline-bookmarks.json"))
}
