import Foundation

public struct ApplicationPassport: Identifiable, Sendable, Hashable {
    public let id: String
    public let firstOnline: Date
    public let lastOnline: Date
    public let daysSeen: Int
    public let observations: Int
    public let uniqueDestinations: Int
    public let typicalPorts: [String]
    public let typicalCountries: [String]
    public let typicalConnectionsPerDay: ClosedRange<Int>
    public let confidence: Int
    public let totalBytes: UInt64?
}

public struct AddressMemory: Identifiable, Sendable, Hashable {
    public let id: String
    public let firstSeen: Date
    public let lastSeen: Date
    public let daysSeen: Int
    public let observations: Int
    public let processes: [String]
    public let ports: [String]
    public let totalBytes: UInt64?
}

public struct PortUsage: Identifiable, Sendable, Hashable { public let id: String; public let count: Int; public let service: String }
public struct DomainFamilyUsage: Identifiable, Sendable, Hashable { public let id: String; public let count: Int; public let hosts: Int }
public struct DailyNetworkActivity: Identifiable, Sendable, Hashable { public var id: Date { day }; public let day: Date; public let observations: Int; public let processes: Int; public let destinations: Int; public let totalBytes: UInt64? }

public struct NetworkIntelligenceAnalyzer: Sendable {
    private let calendar = Calendar.current
    public init() {}

    public func passports(records: [AppConnectionRecord]) -> [ApplicationPassport] {
        Dictionary(grouping: records, by: \.appBundleIdentifier).map { app, values in
            let sorted = values.sorted { $0.timestamp < $1.timestamp }
            let days = Dictionary(grouping: values, by: { calendar.startOfDay(for: $0.timestamp) })
            let dailyCounts = days.values.map(\.count).sorted()
            let ports = ranked(values.compactMap(\.remotePort), limit: 5)
            let countries = ranked(values.compactMap(\.countryCode), limit: 5)
            let bytes = measuredBytes(values)
            return ApplicationPassport(
                id: app, firstOnline: sorted.first?.timestamp ?? Date(), lastOnline: sorted.last?.timestamp ?? Date(),
                daysSeen: days.count, observations: values.count, uniqueDestinations: Set(values.compactMap(\.remoteAddress)).count,
                typicalPorts: ports, typicalCountries: countries,
                typicalConnectionsPerDay: (dailyCounts.first ?? 0)...(dailyCounts.last ?? 0),
                confidence: min(99, 20 + days.count * 8 + min(40, values.count / 10)), totalBytes: bytes
            )
        }.sorted { $0.observations > $1.observations }
    }

    public func networkMemory(records: [AppConnectionRecord]) -> [AddressMemory] {
        Dictionary(grouping: records.compactMap { record -> AppConnectionRecord? in record.remoteAddress == nil ? nil : record }, by: { $0.remoteAddress! }).map { address, values in
            let sorted = values.sorted { $0.timestamp < $1.timestamp }
            return AddressMemory(
                id: address, firstSeen: sorted.first?.timestamp ?? Date(), lastSeen: sorted.last?.timestamp ?? Date(),
                daysSeen: Set(values.map { calendar.startOfDay(for: $0.timestamp) }).count, observations: values.count,
                processes: ranked(values.map(\.appBundleIdentifier), limit: 5), ports: ranked(values.compactMap(\.remotePort), limit: 8),
                totalBytes: measuredBytes(values)
            )
        }.sorted { $0.lastSeen > $1.lastSeen }
    }

    public func ports(records: [AppConnectionRecord]) -> [PortUsage] {
        Dictionary(grouping: records.compactMap(\.remotePort), by: { $0 }).map {
            PortUsage(id: $0.key, count: $0.value.count, service: ConnectionExplanationService.serviceName(for: $0.key))
        }.sorted { $0.count > $1.count }
    }

    public func domainFamilies(records: [AppConnectionRecord]) -> [DomainFamilyUsage] {
        let hosts = records.compactMap(\.remoteHostname).filter { !$0.isEmpty }
        return Dictionary(grouping: hosts, by: domainFamily).map { family, values in
            DomainFamilyUsage(id: family, count: values.count, hosts: Set(values).count)
        }.sorted { $0.count > $1.count }
    }

    public func calendarActivity(records: [AppConnectionRecord]) -> [DailyNetworkActivity] {
        Dictionary(grouping: records, by: { calendar.startOfDay(for: $0.timestamp) }).map { day, values in
            DailyNetworkActivity(day: day, observations: values.count, processes: Set(values.map(\.appBundleIdentifier)).count,
                                 destinations: Set(values.compactMap(\.remoteAddress)).count, totalBytes: measuredBytes(values))
        }.sorted { $0.day < $1.day }
    }

    public func journal(records: [AppConnectionRecord], day: Date = Date()) -> String {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return "No journal available." }
        let values = records.filter { $0.timestamp >= start && $0.timestamp < end }
        guard !values.isEmpty else { return "No network connection observations were retained for \(start.formatted(date: .long, time: .omitted))." }
        let apps = Dictionary(grouping: values, by: \.appBundleIdentifier).mapValues(\.count).sorted { $0.value > $1.value }
        let top = apps.prefix(3).map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
        let destinations = Set(values.compactMap(\.remoteAddress)).count
        let countries = Set(values.compactMap(\.countryCode)).count
        let blocked = values.filter { $0.ruleAction == .blocked || $0.ruleAction == .manualBlock }.count
        let bytesText = measuredBytes(values).map { " Recorded per-flow traffic totalled \(ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .binary))." } ?? " Per-flow byte totals were unavailable from the active provider."
        return "On \(start.formatted(date: .long, time: .omitted)), GlossWire retained \(values.count.formatted()) connection observations from \(apps.count) processes to \(destinations) unique remote addresses across \(countries) resolved countries. The most active processes were \(top). \(blocked) observations carried a blocked rule outcome.\(bytesText) This journal summarises endpoint metadata and does not inspect packet contents."
    }

    private func ranked(_ values: [String], limit: Int) -> [String] {
        Dictionary(grouping: values, by: { $0 }).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    private func measuredBytes(_ records: [AppConnectionRecord]) -> UInt64? {
        guard records.contains(where: { $0.bytesSent != nil || $0.bytesReceived != nil }) else { return nil }
        return records.reduce(0) { $0 + ($1.bytesSent ?? 0) + ($1.bytesReceived ?? 0) }
    }

    private func domainFamily(_ hostname: String) -> String {
        let parts = hostname.lowercased().split(separator: ".")
        guard parts.count >= 2 else { return hostname.lowercased() }
        return parts.suffix(2).joined(separator: ".")
    }
}
