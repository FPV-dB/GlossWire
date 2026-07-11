import SwiftUI

public struct ReputationBadge: View {
    let matches: [ReputationMatch]

    public init(matches: [ReputationMatch]) {
        self.matches = matches
    }

    public var body: some View {
        if let strongest = strongestMatch {
            Label(strongest.severity.rawValue, systemImage: "exclamationmark.shield")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(color(for: strongest.severity))
                .background(color(for: strongest.severity).opacity(0.14), in: Capsule())
                .help("Matched \(strongest.listName): \(strongest.matchedValue)")
        }
    }

    private var strongestMatch: ReputationMatch? {
        matches.sorted { rank($0.severity) > rank($1.severity) }.first
    }

    private func rank(_ severity: ReputationSeverity) -> Int {
        switch severity {
        case .malwareSecurity: 4
        case .privacy: 3
        case .adTracker: 2
        case .info: 1
        }
    }

    private func color(for severity: ReputationSeverity) -> Color {
        switch severity {
        case .malwareSecurity: .red
        case .privacy: .purple
        case .adTracker: .orange
        case .info: .blue
        }
    }
}

public struct ReputationMatchesView: View {
    let matches: [ReputationMatch]
    let blockingEnabled: Bool

    public init(matches: [ReputationMatch], blockingEnabled: Bool = false) {
        self.matches = matches
        self.blockingEnabled = blockingEnabled
    }

    public var body: some View {
        if matches.isEmpty {
            Text("No enabled block list matches for this connection.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(matches) { match in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(match.listName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(match.severity.rawValue)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.12), in: Capsule())
                        }
                        Text(match.matchedValue)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("\(match.category.rawValue) - \(match.matchedRule)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
                Text(blockingEnabled ? "Blocking is enabled. Apply the app-managed PF anchor to enforce matching live connection IP blocks." : "Reputation matches are informational only. Review before blocking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
