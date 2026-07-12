import AppKit
import CoreGraphics
import Foundation

public struct SystemNetworkContext: Hashable, Sendable {
    public let capturedAt: Date; public let tunnelInterfaces: [String]; public let connectedVPNServices: [String]; public let defaultInterface: String?; public let possibleVPNBypass: Bool
    public let dnsAssessment: String; public let idleSeconds: TimeInterval; public let sleepPreventers: [String]
}

public struct SystemContextProvider: Sendable {
    public init() {}
    public func snapshot() async -> SystemNetworkContext {
        async let interfaces = CommandRunner().run("/sbin/ifconfig", arguments: [])
        async let route = CommandRunner().run("/sbin/route", arguments: ["-n", "get", "default"])
        async let dns = CommandRunner().run("/usr/sbin/scutil", arguments: ["--dns"])
        async let vpn = CommandRunner().run("/usr/sbin/scutil", arguments: ["--nc", "list"])
        async let assertions = CommandRunner().run("/usr/bin/pmset", arguments: ["-g", "assertions"])
        let ifResult = try? await interfaces, routeResult = try? await route, dnsResult = try? await dns, vpnResult = try? await vpn, assertionResult = try? await assertions
        let tunnels = Self.vpnInterfaces(ifResult?.output ?? ""), services = Self.connectedVPNServices(vpnResult?.output ?? ""), defaultInterface = Self.defaultInterface(routeResult?.output ?? "")
        let dnsText = dnsResult?.output ?? ""; let dnsAssessment: String
        if services.isEmpty { dnsAssessment = "No connected Network Configuration VPN service detected; DNS leak assessment is not applicable." }
        else if tunnels.contains(where: { dnsText.contains("if_index") && dnsText.contains($0) }) { dnsAssessment = "A tunnel-scoped DNS resolver is visible. Other resolver paths may still exist." }
        else { dnsAssessment = "VPN service connected, but resolver output is not attributable to a tunnel interface; DNS leak status is indeterminate." }
        return SystemNetworkContext(capturedAt: Date(), tunnelInterfaces: tunnels, connectedVPNServices: services, defaultInterface: defaultInterface,
            possibleVPNBypass: !services.isEmpty && !(defaultInterface?.hasPrefix("utun") ?? false), dnsAssessment: dnsAssessment,
            idleSeconds: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null), sleepPreventers: Self.sleepPreventers(assertionResult?.output ?? ""))
    }
    public static func vpnInterfaces(_ text: String) -> [String] { text.split(whereSeparator: \.isNewline).compactMap { line in guard !line.first.map(\.isWhitespace)! else { return nil }; let name = line.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""; return name.hasPrefix("utun") && line.contains("UP") ? name : nil }.sorted() }
    public static func connectedVPNServices(_ text: String) -> [String] { text.split(whereSeparator: \.isNewline).compactMap { line in guard line.contains("(Connected)") else { return nil }; if let quoted = line.split(separator: "\"").dropFirst().first { return String(quoted) }; return line.trimmingCharacters(in: .whitespaces) }.sorted() }
    public static func defaultInterface(_ text: String) -> String? { text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { $0.hasPrefix("interface:") }?.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } }
    public static func sleepPreventers(_ text: String) -> [String] { text.split(whereSeparator: \.isNewline).map(String.init).filter { $0.contains("pid ") && ($0.contains("PreventUserIdleSystemSleep") || $0.contains("PreventSystemSleep")) }.map { $0.trimmingCharacters(in: .whitespaces) } }
}

@MainActor public final class SystemContextViewModel: ObservableObject {
    @Published public private(set) var context: SystemNetworkContext?; @Published public private(set) var refreshing = false; @Published public private(set) var lastWakeAt: Date?
    private var wakeObserver: NSObjectProtocol?
    public init() { wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.lastWakeAt = Date() } } }
    public func refresh() async { guard !refreshing else { return }; refreshing = true; context = await SystemContextProvider().snapshot(); refreshing = false }
}
