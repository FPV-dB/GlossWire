import SwiftUI

public struct BlockListsSettingsView: View {
    @ObservedObject private var store = ReputationBlockListStore.shared

    public init() {}

    public var body: some View {
        Section("Block Lists") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Reputation checking only", systemImage: "info.circle")
                    .font(.headline)
                Text("Enabled lists are used for local reputation matching and alerts. They do not automatically block traffic unless explicit blocking is enabled elsewhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(ReputationBlockListCategory.allCases) { category in
                DisclosureGroup(category.rawValue) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.subscriptions.filter { $0.category == category }) { subscription in
                            BlockListSubscriptionRow(subscription: subscription, enabled: Binding(
                                get: { store.isEnabled(subscription.id) },
                                set: { store.setEnabled(subscription.id, enabled: $0) }
                            ))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            HStack {
                Button("Update enabled lists") {
                    Task { await store.updateEnabledLists() }
                }
                Button("Update all lists") {
                    Task { await store.updateAllLists() }
                }
                Button("Reset to recommended defaults") {
                    store.resetRecommendedDefaults()
                }
            }
            .disabled(store.isUpdating)

            if store.isUpdating {
                ProgressView("Updating lists...")
            }
            if let message = store.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.localizedCaseInsensitiveContains("failed") ? .orange : .secondary)
            }
            LabeledContent("Loaded local rules", value: store.rules.count.formatted())
        }
    }
}

private struct BlockListSubscriptionRow: View {
    let subscription: BlockListSubscription
    @Binding var enabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: $enabled)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(subscription.name)
                        .font(.subheadline.weight(.semibold))
                    Text(subscription.listType.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
                Text(subscription.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subscription.url.absoluteString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                Text("Last updated: \(subscription.lastUpdated.map(Self.dateFormatter.string(from:)) ?? "Never")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
