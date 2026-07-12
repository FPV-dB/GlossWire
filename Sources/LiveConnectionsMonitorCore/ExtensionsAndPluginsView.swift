import SwiftUI

@MainActor final class ExtensionsAndPluginsViewModel: ObservableObject {
    @Published var plugins: [GlossWirePluginDescriptor] = []; @Published var provider: NetworkExtensionProviderStatus?; @Published var loading = false
    func refresh() async { loading = true; async let discovered = GlossWirePluginRegistry().discover(); async let status = NetworkExtensionProviderBridge().status(); plugins = await discovered; provider = await status; loading = false }
}
public struct ExtensionsAndPluginsView: View {
    @StateObject private var model = ExtensionsAndPluginsViewModel()
    public init() {}
    public var body: some View { ZStack { AppBackground(); ScrollView { VStack(alignment: .leading, spacing: 14) {
        HStack { VStack(alignment: .leading) { Text("Extensions & Plugins").font(.title2.weight(.semibold)); Text("Capability declarations, signature validation, and provider readiness.").foregroundStyle(.secondary) }; Spacer(); Button("Refresh") { Task { await model.refresh() } }.disabled(model.loading) }
        GlassCard { VStack(alignment: .leading, spacing: 8) { Text("Network Extension Provider").font(.headline); if let provider = model.provider { LabeledContent("Readiness", value: provider.readiness.rawValue); Text(provider.detail).font(.caption).foregroundStyle(.secondary); LabeledContent("Per-flow bytes", value: provider.capabilities.suppliesPerFlowBytes ? "Available" : "Unavailable"); LabeledContent("Per-app enforcement", value: provider.capabilities.enforcesPerAppRules ? "Available" : "Unavailable") }; Text("GlossWire never claims extension capabilities until an embedded, entitled, user-approved provider is active.").font(.caption).foregroundStyle(.secondary) } }
        GlassCard { VStack(alignment: .leading, spacing: 8) { Text("Plugin Registry").font(.headline); Text("Scans Application Support/GlossWire/Plugins and the legacy support folder. Executable plugins require a valid TeamIdentifier and are not loaded into the main process.").font(.caption).foregroundStyle(.secondary); if model.plugins.isEmpty { Text("No plugin manifests discovered.").foregroundStyle(.secondary) }; ForEach(model.plugins) { plugin in HStack { VStack(alignment: .leading) { Text("\(plugin.manifest.name) \(plugin.manifest.version)").font(.subheadline.weight(.semibold)); Text(plugin.manifest.identifier).font(.caption.monospaced()); Text(plugin.manifest.capabilities.map(\.rawValue).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary); Text(plugin.detail).font(.caption2).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { Text(plugin.state.rawValue); Text(plugin.teamIdentifier ?? "No team").font(.caption.monospaced()) } } } } }
    }.padding(16) } }.task { await model.refresh() } }
}
