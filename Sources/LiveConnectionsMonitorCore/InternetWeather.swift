import Foundation

public struct InternetWeatherSample: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID; public let timestamp: Date; public let latencyMS: Double?; public let packetLossPercent: Double?
    public let dnsResponseMS: Double?; public let ipv4Available: Bool; public let ipv6Available: Bool; public let gateway: String?
    public init(id: UUID = UUID(), timestamp: Date = Date(), latencyMS: Double?, packetLossPercent: Double?, dnsResponseMS: Double?, ipv4Available: Bool, ipv6Available: Bool, gateway: String?) { self.id = id; self.timestamp = timestamp; self.latencyMS = latencyMS; self.packetLossPercent = packetLossPercent; self.dnsResponseMS = dnsResponseMS; self.ipv4Available = ipv4Available; self.ipv6Available = ipv6Available; self.gateway = gateway }
}

public struct InternetWeatherService: Sendable {
    private let runner: CommandRunner
    public init(runner: CommandRunner = CommandRunner()) { self.runner = runner }
    public func measure() async -> InternetWeatherSample {
        async let ping = runner.run("/sbin/ping", arguments: ["-c", "3", "-W", "1000", "1.1.1.1"])
        async let dns = runner.run("/usr/bin/dig", arguments: ["+stats", "+time=2", "+tries=1", "example.com", "A"])
        async let route4 = runner.run("/sbin/route", arguments: ["-n", "get", "default"])
        async let route6 = runner.run("/sbin/route", arguments: ["-n", "get", "-inet6", "default"])
        let pingResult = try? await ping, dnsResult = try? await dns, ipv4 = try? await route4, ipv6 = try? await route6
        let pingText = (pingResult?.output ?? "") + (pingResult?.errorOutput ?? "")
        return InternetWeatherSample(latencyMS: Self.averageLatency(pingText), packetLossPercent: Self.packetLoss(pingText),
            dnsResponseMS: Self.dnsTime(dnsResult?.output ?? ""), ipv4Available: ipv4?.exitCode == 0,
            ipv6Available: ipv6?.exitCode == 0, gateway: Self.gateway(ipv4?.output ?? ""))
    }
    public static func averageLatency(_ text: String) -> Double? { text.split(whereSeparator: \.isNewline).first { $0.contains("round-trip") || $0.contains("rtt min") }.flatMap { line in line.split(separator: "=").last?.split(separator: "/").dropFirst().first.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } } }
    public static func packetLoss(_ text: String) -> Double? { text.split(whereSeparator: \.isNewline).first { $0.contains("packet loss") }.flatMap { line in line.split(separator: ",").first { $0.contains("packet loss") }?.split(separator: "%").first?.split(separator: " ").last.flatMap { Double($0) } } }
    public static func dnsTime(_ text: String) -> Double? { text.split(whereSeparator: \.isNewline).first { $0.contains("Query time:") }.flatMap { line in line.split(separator: " ").first(where: { Double($0) != nil }).flatMap { Double($0) } } }
    public static func gateway(_ text: String) -> String? { text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { $0.hasPrefix("gateway:") }?.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } }
}

public actor InternetWeatherStore {
    private let url: URL
    public init(url: URL? = nil) { let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser; self.url = url ?? base.appendingPathComponent("Live Connections Monitor/internet-weather.json") }
    public func load() -> [InternetWeatherSample] { guard let data = try? Data(contentsOf: url) else { return [] }; return (try? JSONDecoder().decode([InternetWeatherSample].self, from: data)) ?? [] }
    public func append(_ sample: InternetWeatherSample) throws { guard !GlossWireLogPolicy.isDisabled else { return }; var values = load(); values.append(sample); if values.count > 10_000 { values.removeFirst(values.count - 10_000) }; try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(values).write(to: url, options: .atomic) }
}

@MainActor public final class InternetWeatherViewModel: ObservableObject {
    @Published public private(set) var samples: [InternetWeatherSample] = []; @Published public private(set) var measuring = false; @Published public var error: String?
    private let service: InternetWeatherService; private let store: InternetWeatherStore
    public init(service: InternetWeatherService = InternetWeatherService(), store: InternetWeatherStore = InternetWeatherStore()) { self.service = service; self.store = store }
    public var latest: InternetWeatherSample? { samples.last }
    public func load() async { samples = await store.load() }
    public func refresh() async { guard !measuring else { return }; measuring = true; let sample = await service.measure(); do { try await store.append(sample); samples = await store.load(); if GlossWireLogPolicy.isDisabled { samples.append(sample) } } catch { self.error = error.localizedDescription }; measuring = false }
}
