import Foundation
import Testing
@testable import LiveConnectionsMonitorCore

@Test func pluginValidatorAcceptsSafeDataPluginsAndRejectsCapabilityEscalation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true); defer { try? FileManager.default.removeItem(at: directory) }; try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let safe = GlossWirePluginManifest(identifier: "test.catalog", name: "Catalog", version: "1.0", apiVersion: 1, capabilities: [.metadataCatalog], executable: nil, minimumGlossWireVersion: nil)
    #expect(await GlossWirePluginValidator().validate(manifest: safe, directory: directory).state == .dataOnly)
    let unsafe = GlossWirePluginManifest(identifier: "test.discovery", name: "Discovery", version: "1.0", apiVersion: 1, capabilities: [.networkDiscovery], executable: nil, minimumGlossWireVersion: nil)
    #expect(await GlossWirePluginValidator().validate(manifest: unsafe, directory: directory).state == .invalid)
}

@Test func pluginRegistryDiscoversManifestAndNetworkExtensionStaysGated() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true), plugin = root.appendingPathComponent("Catalog", isDirectory: true); defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: true)
    let manifest = GlossWirePluginManifest(identifier: "test.catalog", name: "Catalog", version: "1.0", apiVersion: 1, capabilities: [.serviceRecognition], executable: nil, minimumGlossWireVersion: nil)
    try JSONEncoder().encode(manifest).write(to: plugin.appendingPathComponent("plugin.json"))
    #expect(await GlossWirePluginRegistry(roots: [root]).discover().count == 1)
    let emptyApp = root.appendingPathComponent("GlossWire.app", isDirectory: true); try FileManager.default.createDirectory(at: emptyApp, withIntermediateDirectories: true)
    let status = await NetworkExtensionProviderBridge().status(appBundleURL: emptyApp)
    #expect(status.readiness == .extensionMissing); #expect(!status.capabilities.suppliesPerFlowBytes); #expect(!status.capabilities.enforcesPerAppRules)
}
