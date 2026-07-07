import SwiftUI

public enum ConnectionRiskLevel: String, CaseIterable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case blocked = "Blocked"
    case unknown = "Unknown"

    public var icon: String {
        switch self {
        case .low: "checkmark.shield"
        case .medium: "exclamationmark.triangle"
        case .high: "flame"
        case .blocked: "hand.raised.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

public struct RiskBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("visual.highContrastMode") private var highContrastMode = false
    let level: ConnectionRiskLevel

    public init(_ level: ConnectionRiskLevel) {
        self.level = level
    }

    public var body: some View {
        let theme = VisualTheme(colorScheme: colorScheme, highContrast: highContrastMode)
        Label(level.rawValue, systemImage: level.icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(gradient(theme: theme), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1))
            .accessibilityLabel("Risk \(level.rawValue)")
    }

    private func gradient(theme: VisualTheme) -> LinearGradient {
        switch level {
        case .low: theme.successGradient
        case .medium: theme.warningGradient
        case .high, .blocked: theme.dangerGradient
        case .unknown: theme.inactiveGradient
        }
    }
}
