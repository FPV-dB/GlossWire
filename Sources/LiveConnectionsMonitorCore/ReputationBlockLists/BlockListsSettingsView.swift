import SwiftUI

public struct BlockListsSettingsView: View {
    @ObservedObject private var store = ReputationBlockListStore.shared
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        Section("Block Lists") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Local reputation lists", systemImage: "info.circle")
                    .font(.headline)
                Text("Enabled lists are checked locally against live connection destinations. Blocking is only active when the Firewall setting to block matching live connections is enabled and the app-managed PF anchor is applied.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Search \(store.subscriptions.count) block lists", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ForEach(ReputationBlockListCategory.allCases) { category in
                let categorySubscriptions = visibleSubscriptions.filter { $0.category == category }
                if !categorySubscriptions.isEmpty {
                    DisclosureGroup("\(category.rawValue) (\(categorySubscriptions.count))") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(categorySubscriptions) { subscription in
                            BlockListSubscriptionRow(subscription: subscription, enabled: Binding(
                                get: { store.isEnabled(subscription.id) },
                                set: { store.setEnabled(subscription.id, enabled: $0) }
                            ))
                        }
                    }
                    .padding(.vertical, 6)
                }
                }
            }

            HStack {
                Button("Block all lists") {
                    store.enableAllLists()
                }
                .buttonStyle(.borderedProminent)
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

            Text("Block all lists enables every subscription here. Enforcement still requires the Firewall option to block reputation matches and an applied PF anchor.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
        .task { await store.loadFireHOLCatalog() }
    }

    private var visibleSubscriptions: [BlockListSubscription] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.subscriptions }
        return store.subscriptions.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.url.absoluteString.localizedCaseInsensitiveContains(query)
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
