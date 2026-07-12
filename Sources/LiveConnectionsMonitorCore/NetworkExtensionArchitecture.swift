import Foundation

public enum NetworkExtensionReadiness: String, Sendable { case unavailable = "Unavailable", extensionMissing = "Extension missing", entitlementMissing = "Entitlement missing", approvalRequired = "Approval required", ready = "Ready" }
public struct NetworkExtensionProviderStatus: Sendable {
    public let readiness: NetworkExtensionReadiness; public let detail: String; public let capabilities: AppProviderCapabilities
}
public struct NetworkExtensionFlowEvent: Codable, Hashable, Sendable {
    public let id: UUID; public let timestamp: Date; public let processIdentifier: Int; public let auditTokenHash: String?; public let direction: String
    public let localEndpoint: String; public let remoteEndpoint: String; public let hostname: String?; public let bytesSent: UInt64; public let bytesReceived: UInt64; public let openedAt: Date; public let closedAt: Date?
}

public struct NetworkExtensionProviderBridge: Sendable {
    public static let expectedExtensionBundleIdentifier = "com.fpvdB.GlossWire.FlowProvider"
    public init() {}
    public func status(appBundleURL: URL? = Bundle.main.bundleURL, entitlementsText: String? = nil) async -> NetworkExtensionProviderStatus {
        guard let appBundleURL else { return unavailable(.unavailable, "Application bundle is unavailable.") }
        let candidates = [appBundleURL.appendingPathComponent("Contents/Library/SystemExtensions/GlossWireFlowProvider.systemextension"), appBundleURL.appendingPathComponent("Contents/PlugIns/GlossWireFlowProvider.appex")]
        guard candidates.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return unavailable(.extensionMissing, "No signed GlossWire flow-provider extension is embedded. Polling metadata provider remains active.") }
        let entitlements: String
        if let entitlementsText { entitlements = entitlementsText }
        else { let result = try? await CommandRunner().run("/usr/bin/codesign", arguments: ["-d", "--entitlements", ":-", appBundleURL.path]); entitlements = (result?.output ?? "") + (result?.errorOutput ?? "") }
        guard entitlements.contains("com.apple.developer.networking.networkextension") else { return unavailable(.entitlementMissing, "The app signature does not contain the required Apple Network Extension entitlement.") }
        return NetworkExtensionProviderStatus(readiness: .approvalRequired, detail: "Extension is embedded and entitled. User approval and provider activation are still required before flow telemetry can be claimed.", capabilities: .processCounters)
    }
    private func unavailable(_ readiness: NetworkExtensionReadiness, _ detail: String) -> NetworkExtensionProviderStatus { NetworkExtensionProviderStatus(readiness: readiness, detail: detail, capabilities: .processCounters) }
}

public protocol NetworkExtensionFlowTransport: Sendable {
    func events(since: Date?) async throws -> [NetworkExtensionFlowEvent]
    func providerCapabilities() async -> AppProviderCapabilities
}
