import Foundation

public struct InvestigationPackageExporter: Sendable {
    public init() {}
    public func export(to destination: URL, records: [AppConnectionRecord], weather: [InternetWeatherSample], bookmarks: [TimelineBookmark], privacyMode: Bool) async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("GlossWire-Investigation-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let analyzer = NetworkIntelligenceAnalyzer()
        try analyzer.journal(records: records).write(to: root.appendingPathComponent("network-journal.txt"), atomically: true, encoding: .utf8)
        try summary(records: records, weather: weather, bookmarks: bookmarks).write(to: root.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        try csv(records: records, privacyMode: privacyMode).write(to: root.appendingPathComponent("connections.csv"), atomically: true, encoding: .utf8)
        try jsonRecords(records, privacyMode: privacyMode).write(to: root.appendingPathComponent("connections.json"), options: .atomic)
        try encoded(weather).write(to: root.appendingPathComponent("internet-weather.json"), options: .atomic)
        try encoded(bookmarks).write(to: root.appendingPathComponent("timeline-bookmarks.json"), options: .atomic)
        try capabilityManifest.write(to: root.appendingPathComponent("CAPABILITIES.txt"), atomically: true, encoding: .utf8)
        try? fm.removeItem(at: destination)
        let result = try await CommandRunner().run("/usr/bin/ditto", arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", root.path, destination.path])
        guard result.exitCode == 0 else { throw CommandRunnerError.failed(path: "/usr/bin/ditto", code: result.exitCode, output: result.errorOutput) }
    }

    private func summary(records: [AppConnectionRecord], weather: [InternetWeatherSample], bookmarks: [TimelineBookmark]) -> String {
        """
        GlossWire Investigation Package
        Generated: \(Date().formatted(date: .long, time: .standard))

        Connection observations: \(records.count)
        Processes: \(Set(records.map(\.appBundleIdentifier)).count)
        Remote addresses: \(Set(records.compactMap(\.remoteAddress)).count)
        Weather samples: \(weather.count)
        Timeline bookmarks: \(bookmarks.count)

        This package contains retained endpoint metadata only. See CAPABILITIES.txt before drawing conclusions.
        """
    }

    private func csv(records: [AppConnectionRecord], privacyMode: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        let header = "time,process,pid,direction,protocol,local_address,local_port,remote_address,remote_port,hostname,country,state,duration,rule"
        let rows = records.map { record in
            let fields: [String] = [
                formatter.string(from: record.timestamp), PrivacyRedactor.process(record.appBundleIdentifier, enabled: privacyMode),
                String(record.pid), record.direction.rawValue, record.protocolKind.rawValue,
                PrivacyRedactor.address(record.localAddress, enabled: privacyMode), record.localPort,
                PrivacyRedactor.address(record.remoteAddress, enabled: privacyMode), record.remotePort ?? "",
                PrivacyRedactor.hostname(record.remoteHostname, enabled: privacyMode) ?? "", record.countryCode ?? "",
                record.state, String(format: "%.3f", record.duration), record.ruleAction.rawValue
            ]
            return fields.map(csvEscape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private func jsonRecords(_ records: [AppConnectionRecord], privacyMode: Bool) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let objects: [[String: Any]] = records.map { record in
            [
                "id": record.id, "timestamp": formatter.string(from: record.timestamp),
                "process": PrivacyRedactor.process(record.appBundleIdentifier, enabled: privacyMode), "pid": record.pid,
                "direction": record.direction.rawValue, "protocol": record.protocolKind.rawValue,
                "localAddress": PrivacyRedactor.address(record.localAddress, enabled: privacyMode), "localPort": record.localPort,
                "remoteAddress": PrivacyRedactor.address(record.remoteAddress, enabled: privacyMode), "remotePort": record.remotePort ?? "",
                "hostname": PrivacyRedactor.hostname(record.remoteHostname, enabled: privacyMode) ?? "", "country": record.countryCode ?? "",
                "state": record.state, "duration": record.duration, "rule": record.ruleAction.rawValue
            ]
        }
        return try JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])
    }
    private func encoded<T: Encodable>(_ value: T) throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return try encoder.encode(value) }
    private func csvEscape(_ value: String) -> String { let escaped = value.replacingOccurrences(of: "\"", with: "\"\""); return value.contains(",") || value.contains("\"") || value.contains("\n") ? "\"\(escaped)\"" : escaped }
    private var capabilityManifest: String { """
        GlossWire Evidence Capabilities

        INCLUDED
        - Retained process and socket endpoint observations
        - Rule outcomes stored with those observations
        - Locally measured Internet Weather history
        - User-created Timeline bookmarks

        NOT INCLUDED OR INFERRED
        - Packet payloads or packet capture
        - DNS resolver event stream or DNS cache contents
        - Per-flow bytes when the active provider does not supply them
        - TLS certificates or decrypted traffic
        - Definitive malware, VPN leak, port-scan, or identity conclusions

        Absence from this package is not proof that an event did not occur. Retention settings and Disable all logs can limit the available evidence.
        """ }
}
