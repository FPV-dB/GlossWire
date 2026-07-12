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
public enum BehaviourSignalKind: String, Sendable, Hashable { case beacon = "Periodic beacon", ipv6 = "IPv6 activity", uploadSpike = "Upload spike" }
public struct BehaviourSignal: Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: BehaviourSignalKind
    public let process: String
    public let detail: String
    public let confidence: Int
}
public struct DetectionCapability: Identifiable, Sendable, Hashable { public let id: String; public let available: Bool; public let detail: String }
public struct ApplicationInternetRating: Identifiable, Sendable, Hashable {
    public let id: String; public let score: Int; public let label: String; public let encryptedPercent: Int
    public let destinationEntropy: Double; public let observationsPerHour: Double; public let explanation: String
}
public struct NetworkFingerprint: Sendable, Hashable { public let similarityPercent: Int?; public let currentSignature: String; public let previousSignature: String? }

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

    public func behaviourSignals(records: [AppConnectionRecord]) -> [BehaviourSignal] {
        var signals = periodicSignals(records: records)
        for (process, values) in Dictionary(grouping: records.filter { record in
            record.remoteAddress?.contains(":") == true && !record.remoteAddress!.lowercased().hasPrefix("fe80:")
        }, by: \.appBundleIdentifier) {
            signals.append(BehaviourSignal(id: "ipv6:\(process)", kind: .ipv6, process: process,
                                           detail: "\(values.count) retained connection observations used non-link-local IPv6.", confidence: 100))
        }
        signals.sort { $0.confidence > $1.confidence }
        return signals
    }

    public func detectionCapabilities(provider: AppProviderCapabilities) -> [DetectionCapability] {
        [
            DetectionCapability(id: "Periodic beacon detection", available: true, detail: "Uses repeated endpoint timestamps; it is a pattern hint, not a malware verdict."),
            DetectionCapability(id: "IPv6 activity", available: true, detail: "Uses retained remote-address metadata."),
            DetectionCapability(id: "Upload spike detection", available: provider.suppliesPerFlowBytes, detail: provider.suppliesPerFlowBytes ? "Available from measured per-flow byte counters." : "Needs a future provider with measured per-flow byte counters."),
            DetectionCapability(id: "Wake and idle attribution", available: false, detail: "Needs durable power-state events correlated with connection observations."),
            DetectionCapability(id: "VPN and DNS leak detection", available: false, detail: "Needs route, interface, and DNS resolver attribution from a future system provider."),
            DetectionCapability(id: "Executable change detection", available: true, detail: "Hashes readable running-app executables and compares durable signer/team identity snapshots."),
            DetectionCapability(id: "Inbound port-scan detection", available: false, detail: "Needs inbound attempt telemetry; established-socket polling cannot prove scans.")
        ]
    }

    public func internetRatings(records: [AppConnectionRecord]) -> [ApplicationInternetRating] {
        Dictionary(grouping: records, by: \.appBundleIdentifier).map { process, values in
            let destinations = values.compactMap(\.remoteAddress)
            let counts = Dictionary(grouping: destinations, by: { $0 }).mapValues(\.count)
            let entropy = shannonEntropy(Array(counts.values))
            let encrypted = values.filter { ["443", "853", "993", "995", "465"].contains($0.remotePort ?? "") }.count
            let encryptedPercent = values.isEmpty ? 0 : Int(Double(encrypted) / Double(values.count) * 100)
            let countries = Set(values.compactMap(\.countryCode)).count
            let unusualPenalty = min(25, max(0, countries - 5) * 3) + min(20, Int(entropy * 3))
            let consistencyBonus = min(20, values.count / 20)
            let score = min(100, max(0, 55 + encryptedPercent / 4 + consistencyBonus - unusualPenalty))
            let span = max(3600, (values.map(\.timestamp).max() ?? Date()).timeIntervalSince(values.map(\.timestamp).min() ?? Date()))
            let rate = Double(values.count) / (span / 3600)
            let label = score >= 85 ? "Excellent" : score >= 70 ? "Good" : score >= 50 ? "Variable" : "Review"
            return ApplicationInternetRating(id: process, score: score, label: label, encryptedPercent: encryptedPercent,
                destinationEntropy: entropy, observationsPerHour: rate,
                explanation: "Based on endpoint diversity, resolved-country spread, conventional encrypted-service ports, observation volume, and historical consistency. It does not inspect content or certify trust.")
        }.sorted { $0.score > $1.score }
    }

    public func fingerprint(records: [AppConnectionRecord], now: Date = Date()) -> NetworkFingerprint {
        let calendar = Calendar.current; let today = calendar.startOfDay(for: now); let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let current = records.filter { $0.timestamp >= today && $0.timestamp <= now }
        let previous = records.filter { $0.timestamp >= yesterday && $0.timestamp < today }
        let a = signatureTokens(current), b = signatureTokens(previous)
        let union = a.union(b); let similarity = union.isEmpty || a.isEmpty || b.isEmpty ? nil : Int(Double(a.intersection(b).count) / Double(union.count) * 100)
        return NetworkFingerprint(similarityPercent: similarity, currentSignature: stableSignature(a), previousSignature: b.isEmpty ? nil : stableSignature(b))
    }

    public func explainMyComputer(records: [AppConnectionRecord], now: Date = Date(), interval: TimeInterval = 60) -> String {
        let recent = records.filter { $0.timestamp >= now.addingTimeInterval(-interval) && $0.timestamp <= now }
        guard !recent.isEmpty else { return "GlossWire did not retain any connection observations during the selected one-minute explanation window." }
        let apps = Dictionary(grouping: recent, by: \.appBundleIdentifier).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
        let top = apps.prefix(3).map { "\($0.0) (\($0.1))" }.joined(separator: ", ")
        let remotes = Set(recent.compactMap(\.remoteAddress)).count, ipv6 = recent.filter { $0.remoteAddress?.contains(":") == true }.count
        let blocked = recent.filter { $0.ruleAction == .blocked || $0.ruleAction == .manualBlock }.count
        return "During the last minute, GlossWire retained \(recent.count) connection observations from \(apps.count) processes to \(remotes) remote addresses. The most active were \(top). \(ipv6) observations used IPv6 and \(blocked) carried a blocked rule outcome. This local explanation uses endpoint metadata only and does not inspect traffic contents or certify destination safety."
    }

    private func shannonEntropy(_ counts: [Int]) -> Double { let total = Double(counts.reduce(0, +)); guard total > 0 else { return 0 }; return -counts.reduce(0) { sum, count in let p = Double(count) / total; return sum + p * log2(p) } }
    private func signatureTokens(_ records: [AppConnectionRecord]) -> Set<String> { Set(records.flatMap { ["app:\($0.appBundleIdentifier)", "port:\($0.remotePort ?? "")", "country:\($0.countryCode ?? "")"] }) }
    private func stableSignature(_ tokens: Set<String>) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in tokens.sorted().joined(separator: "|").utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return String(format: "%016llx", hash)
    }

    private func periodicSignals(records: [AppConnectionRecord]) -> [BehaviourSignal] {
        let grouped = Dictionary(grouping: records.filter { $0.remoteAddress != nil }) { "\($0.appBundleIdentifier)|\($0.remoteAddress!)|\($0.remotePort ?? "")" }
        return grouped.compactMap { key, values in
            let times = values.map(\.timestamp).sorted()
            guard times.count >= 5 else { return nil }
            let intervals = zip(times.dropFirst(), times).map { $0.timeIntervalSince($1) }.filter { $0 >= 10 }
            guard intervals.count >= 4 else { return nil }
            let average = intervals.reduce(0, +) / Double(intervals.count)
            let deviation = intervals.map { abs($0 - average) }.reduce(0, +) / Double(intervals.count)
            let regularity = max(0, 1 - deviation / max(average, 1))
            guard regularity >= 0.85 else { return nil }
            let process = key.split(separator: "|", maxSplits: 1).first.map(String.init) ?? "Unknown"
            let interval = Duration.seconds(average).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
            return BehaviourSignal(id: "beacon:\(key)", kind: .beacon, process: process,
                                   detail: "Repeated the same endpoint about every \(interval) across \(times.count) observations.", confidence: Int(regularity * 100))
        }
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
