import Foundation

public enum NmapScanStatus: String, Codable, Sendable {
    case ready = "Ready"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public enum NmapPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case quick = "Quick Nmap Scan"
    case serviceVersion = "Service/Version Scan"
    case osDetection = "OS Detection Scan"
    case aggressive = "Aggressive Scan"
    case custom = "Custom"

    public var id: String { rawValue }

    public var category: NmapPresetCategory {
        switch self {
        case .quick: .portDiscovery
        case .serviceVersion: .serviceEnumeration
        case .osDetection: .osDetection
        case .aggressive: .performance
        case .custom: .hostDiscovery
        }
    }

    public func arguments(target: String) -> [String] {
        switch self {
        case .quick:
            return ["-T4", "-F", target]
        case .serviceVersion:
            return ["-sV", "-T4", target]
        case .osDetection:
            return ["-O", "-T4", target]
        case .aggressive:
            return ["-A", "-T4", target]
        case .custom:
            return [target]
        }
    }
}

public enum NmapPresetCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case hostDiscovery = "Host Discovery"
    case portDiscovery = "Port Discovery"
    case serviceEnumeration = "Service Enumeration"
    case osDetection = "OS Detection"
    case nseScripts = "NSE Scripts"
    case routing = "Routing"
    case performance = "Performance"

    public var id: String { rawValue }
}

public struct NmapWorkbenchPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var category: NmapPresetCategory
    public var arguments: [String]

    public static let builtIns: [NmapWorkbenchPreset] = [
        .init(id: "host-ping", name: "Ping Discovery", category: .hostDiscovery, arguments: ["-sn"]),
        .init(id: "host-list", name: "List Scan", category: .hostDiscovery, arguments: ["-sL"]),
        .init(id: "ports-fast", name: "Fast Top Ports", category: .portDiscovery, arguments: ["-T4", "-F"]),
        .init(id: "ports-top1000", name: "Top 1000 TCP Ports", category: .portDiscovery, arguments: ["-T4", "--top-ports", "1000"]),
        .init(id: "service-version", name: "Service Versions", category: .serviceEnumeration, arguments: ["-sV", "-T4"]),
        .init(id: "service-default", name: "Default Scripts + Versions", category: .serviceEnumeration, arguments: ["-sC", "-sV", "-T4"]),
        .init(id: "os-basic", name: "OS Detection", category: .osDetection, arguments: ["-O", "-T4"]),
        .init(id: "nse-safe", name: "Safe NSE Scripts", category: .nseScripts, arguments: ["--script", "safe", "-T3"]),
        .init(id: "route-trace", name: "Traceroute", category: .routing, arguments: ["--traceroute", "-T3"]),
        .init(id: "perf-aggressive", name: "Aggressive Local Scan", category: .performance, arguments: ["-A", "-T4"])
    ]
}

public enum NmapPortMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case topPorts = "Top ports"
    case commonPorts = "Common ports"
    case allPorts = "All ports"
    case customPortList = "Custom port list"

    public var id: String { rawValue }

    public func arguments(customPorts: String) -> [String] {
        switch self {
        case .topPorts:
            return ["--top-ports", "100"]
        case .commonPorts:
            return ["-F"]
        case .allPorts:
            return ["-p", "-"]
        case .customPortList:
            let cleaned = customPorts.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? [] : ["-p", cleaned]
        }
    }
}

public enum NmapTiming: String, CaseIterable, Identifiable, Codable, Sendable {
    case t2 = "T2"
    case t3 = "T3"
    case t4 = "T4"
    case t5 = "T5"

    public var id: String { rawValue }
    public var argument: String { "-\(rawValue)" }
}

public struct NmapCustomScanConfiguration: Equatable, Hashable, Codable, Sendable {
    public var targetIP: String
    public var portMode: NmapPortMode = .topPorts
    public var customPorts = ""
    public var pingScan = false
    public var serviceDetection = false
    public var osDetection = false
    public var defaultScripts = false
    public var traceroute = false
    public var udpScan = false
    public var timing: NmapTiming = .t4
    public var extraArguments = ""

    public init(targetIP: String) {
        self.targetIP = targetIP
    }

    public func arguments() throws -> [String] {
        var values: [String] = []
        values.append(timing.argument)
        values.append(contentsOf: portMode.arguments(customPorts: customPorts))
        if pingScan { values.append("-sn") }
        if serviceDetection { values.append("-sV") }
        if osDetection { values.append("-O") }
        if defaultScripts { values.append("-sC") }
        if traceroute { values.append("--traceroute") }
        if udpScan { values.append("-sU") }
        values.append(contentsOf: try Self.extraArgumentValues(extraArguments))
        values.append(targetIP.trimmingCharacters(in: .whitespacesAndNewlines))
        return values
    }

    public static func extraArgumentValues(_ rawValue: String) throws -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let forbidden = CharacterSet(charactersIn: ";&|`$><")
        if trimmed.rangeOfCharacter(from: forbidden) != nil {
            throw NmapScanError.invalidExtraArguments
        }
        return trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

public struct NmapParsedPort: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(port)/\(protocolName)" }
    public var port: String
    public var protocolName: String
    public var state: String
    public var service: String
    public var version: String
}

public struct NmapParsedSummary: Codable, Hashable, Sendable {
    public var hostStatus: String?
    public var hostname: String?
    public var vendor: String?
    public var macAddress: String?
    public var osFingerprint: String?
    public var rtt: String?
    public var openPorts: [NmapParsedPort] = []

    public var isEmpty: Bool {
        hostStatus == nil && hostname == nil && vendor == nil && macAddress == nil && osFingerprint == nil && rtt == nil && openPorts.isEmpty
    }
}

public struct NmapScanComparison: Hashable, Sendable {
    public var newlyOpenedPorts: [NmapParsedPort] = []
    public var closedPorts: [NmapParsedPort] = []
    public var serviceVersionChanges: [String] = []
    public var hostnameChanged: String?
    public var osFingerprintChanged: String?

    public var isEmpty: Bool {
        newlyOpenedPorts.isEmpty && closedPorts.isEmpty && serviceVersionChanges.isEmpty && hostnameChanged == nil && osFingerprintChanged == nil
    }
}

public enum NmapExportFormat: String, CaseIterable, Identifiable, Sendable {
    case txt = "TXT"
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case pdf = "PDF"

    public var id: String { rawValue }
    public var fileExtension: String { rawValue.lowercased() }
}

public struct NmapFavouriteProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var configuration: NmapCustomScanConfiguration
}

public struct NmapScanHistoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var targetIP: String
    public var presetName: String
    public var commandArguments: [String]
    public var rawOutput: String
    public var parsedSummary: NmapParsedSummary?
    public var startDate: Date
    public var endDate: Date?
    public var exitCode: Int32?
}

public enum NmapScanError: LocalizedError, Sendable {
    case publicTarget
    case nmapMissing
    case invalidExtraArguments
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .publicTarget:
            return "This feature is limited to local/private IP addresses."
        case .nmapMissing:
            return "Nmap was not found. Install it with Homebrew using: brew install nmap"
        case .invalidExtraArguments:
            return "Extra arguments cannot contain shell metacharacters such as ; & | ` $ > <"
        case let .launchFailed(message):
            return message
        }
    }
}

public enum NmapOutputParser {
    public static func parse(_ output: String) -> NmapParsedSummary? {
        var summary = NmapParsedSummary()
        var sawPortHeader = false

        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("Host is ") {
                summary.hostStatus = line
                if line.contains("latency") {
                    summary.rtt = line
                }
            } else if line.hasPrefix("Nmap scan report for ") {
                summary.hostname = parseHostname(line)
            } else if line.hasPrefix("MAC Address: ") {
                parseMAC(line, into: &summary)
            } else if line.hasPrefix("OS details: ") {
                summary.osFingerprint = String(line.dropFirst("OS details: ".count))
            } else if line.hasPrefix("Running: "), summary.osFingerprint == nil {
                summary.osFingerprint = String(line.dropFirst("Running: ".count))
            } else if line.hasPrefix("PORT") {
                sawPortHeader = true
            } else if sawPortHeader, let parsed = parsePortLine(line) {
                summary.openPorts.append(parsed)
            }
        }

        return summary.isEmpty ? nil : summary
    }

    public static func compare(current: NmapParsedSummary?, previous: NmapParsedSummary?) -> NmapScanComparison? {
        guard let current, let previous else { return nil }
        let currentPorts = Dictionary(uniqueKeysWithValues: current.openPorts.map { ($0.id, $0) })
        let previousPorts = Dictionary(uniqueKeysWithValues: previous.openPorts.map { ($0.id, $0) })
        let currentKeys = Set(currentPorts.keys)
        let previousKeys = Set(previousPorts.keys)
        var comparison = NmapScanComparison()
        comparison.newlyOpenedPorts = currentKeys.subtracting(previousKeys).compactMap { currentPorts[$0] }.sorted { $0.id < $1.id }
        comparison.closedPorts = previousKeys.subtracting(currentKeys).compactMap { previousPorts[$0] }.sorted { $0.id < $1.id }
        for key in currentKeys.intersection(previousKeys).sorted() {
            guard let current = currentPorts[key], let previous = previousPorts[key],
                  current.version != previous.version || current.service != previous.service else { continue }
            comparison.serviceVersionChanges.append("\(key): \(previous.service) \(previous.version) -> \(current.service) \(current.version)")
        }
        if current.hostname != previous.hostname {
            comparison.hostnameChanged = "\(previous.hostname ?? "-") -> \(current.hostname ?? "-")"
        }
        if current.osFingerprint != previous.osFingerprint {
            comparison.osFingerprintChanged = "\(previous.osFingerprint ?? "-") -> \(current.osFingerprint ?? "-")"
        }
        return comparison.isEmpty ? nil : comparison
    }

    private static func parsePortLine(_ line: String) -> NmapParsedPort? {
        let parts = line.split(maxSplits: 3, whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3, parts[1] == "open" else { return nil }
        let portParts = parts[0].split(separator: "/", maxSplits: 1).map(String.init)
        guard portParts.count == 2 else { return nil }
        return NmapParsedPort(
            port: portParts[0],
            protocolName: portParts[1],
            state: parts[1],
            service: parts[2],
            version: parts.count > 3 ? parts[3] : ""
        )
    }

    private static func parseHostname(_ line: String) -> String? {
        let value = String(line.dropFirst("Nmap scan report for ".count))
        if let open = value.lastIndex(of: "("), value.hasSuffix(")") {
            return String(value[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private static func parseMAC(_ line: String, into summary: inout NmapParsedSummary) {
        let value = String(line.dropFirst("MAC Address: ".count))
        if let open = value.firstIndex(of: "("), value.hasSuffix(")") {
            summary.macAddress = String(value[..<open]).trimmingCharacters(in: .whitespaces)
            summary.vendor = String(value[value.index(after: open)..<value.index(before: value.endIndex)])
        } else {
            summary.macAddress = value.trimmingCharacters(in: .whitespaces)
        }
    }
}
