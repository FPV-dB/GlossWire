import Foundation

public struct NetworkChangeSummary: Sendable, Hashable {
    public let currentStart: Date
    public let previousStart: Date
    public let newProcesses: [String]
    public let newDestinations: [String]
    public let newPorts: [String]
    public let disconnectedProcesses: [String]
    public let observationChangePercent: Int?
}

public struct ObservedTopologyNode: Identifiable, Sendable, Hashable {
    public let id: String
    public let address: String
    public let name: String
    public let services: [String]
    public let lastSeen: Date
    public let observationCount: Int
}

public struct NetworkPeriodComparison: Sendable, Hashable {
    public let first: ClosedRange<Date>; public let second: ClosedRange<Date>
    public let firstObservations: Int; public let secondObservations: Int
    public let newProcesses: [String]; public let newDestinations: [String]; public let newCountries: [String]; public let newPorts: [String]
    public var observationChangePercent: Int? { firstObservations == 0 ? nil : Int((Double(secondObservations) / Double(firstObservations) - 1) * 100) }
}

public struct NetworkInvestigationAnalyzer: Sendable {
    public init() {}

    public func changes(records: [AppConnectionRecord], now: Date = Date(), interval: TimeInterval = 3600) -> NetworkChangeSummary {
        let currentStart = now.addingTimeInterval(-interval)
        let previousStart = currentStart.addingTimeInterval(-interval)
        let current = records.filter { $0.timestamp >= currentStart && $0.timestamp <= now }
        let previous = records.filter { $0.timestamp >= previousStart && $0.timestamp < currentStart }
        let currentProcesses = Set(current.map(\.appBundleIdentifier))
        let previousProcesses = Set(previous.map(\.appBundleIdentifier))
        let currentDestinations = Set(current.compactMap(\.remoteAddress))
        let previousDestinations = Set(previous.compactMap(\.remoteAddress))
        let currentPorts = Set(current.compactMap(\.remotePort))
        let previousPorts = Set(previous.compactMap(\.remotePort))
        let percent = previous.isEmpty ? nil : Int(((Double(current.count) / Double(previous.count)) - 1) * 100)
        return NetworkChangeSummary(
            currentStart: currentStart,
            previousStart: previousStart,
            newProcesses: Array(currentProcesses.subtracting(previousProcesses)).sorted(),
            newDestinations: Array(currentDestinations.subtracting(previousDestinations)).sorted(),
            newPorts: Array(currentPorts.subtracting(previousPorts)).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) },
            disconnectedProcesses: Array(previousProcesses.subtracting(currentProcesses)).sorted(),
            observationChangePercent: percent
        )
    }

    public func topology(records: [AppConnectionRecord]) -> [ObservedTopologyNode] {
        let local = records.filter { record in
            guard let address = record.remoteAddress else { return false }
            return Self.isPrivate(address)
        }
        return Dictionary(grouping: local, by: { $0.remoteAddress ?? "" }).compactMap { address, records in
            guard !address.isEmpty, let last = records.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            let services = Set(records.map { ConnectionExplanationService.serviceName(for: $0.remotePort ?? "") }).sorted()
            let name = last.remoteHostname.flatMap { $0.isEmpty ? nil : $0 } ?? Self.deviceHint(services: services)
            return ObservedTopologyNode(id: address, address: address, name: name, services: services, lastSeen: last.timestamp, observationCount: records.count)
        }.sorted { $0.lastSeen > $1.lastSeen }
    }

    public func compare(records: [AppConnectionRecord], first: ClosedRange<Date>, second: ClosedRange<Date>) -> NetworkPeriodComparison {
        let a = records.filter { first.contains($0.timestamp) }; let b = records.filter { second.contains($0.timestamp) }
        func added(_ left: [String], _ right: [String]) -> [String] { Array(Set(right).subtracting(Set(left))).sorted() }
        return NetworkPeriodComparison(first: first, second: second, firstObservations: a.count, secondObservations: b.count,
            newProcesses: added(a.map(\.appBundleIdentifier), b.map(\.appBundleIdentifier)),
            newDestinations: added(a.compactMap(\.remoteAddress), b.compactMap(\.remoteAddress)),
            newCountries: added(a.compactMap(\.countryCode), b.compactMap(\.countryCode)),
            newPorts: added(a.compactMap(\.remotePort), b.compactMap(\.remotePort)))
    }

    private static func isPrivate(_ address: String) -> Bool {
        if address == "::1" || address.lowercased().hasPrefix("fe80:") || address.lowercased().hasPrefix("fd") { return true }
        let parts = address.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        return parts[0] == 10 || (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 192 && parts[1] == 168) || parts[0] == 127
    }

    private static func deviceHint(services: [String]) -> String {
        let text = services.joined(separator: " ").lowercased()
        if text.contains("bonjour") { return "Bonjour device" }
        if text.contains("smb") { return "File server or NAS" }
        if text.contains("http") { return "Local web service" }
        if text.contains("ssh") { return "SSH-capable device" }
        if text.contains("vnc") || text.contains("remote desktop") { return "Remote desktop device" }
        return "Observed LAN device"
    }
}
