import SwiftUI

public struct MetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("visual.highContrastMode") private var highContrastMode = false

    private let title: String
    private let value: String
    private let subtitle: String
    private let systemImage: String
    private let accentGradient: LinearGradient?
    private let trend: String?

    public init(title: String, value: String, subtitle: String = "", systemImage: String, accentGradient: LinearGradient? = nil, trend: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accentGradient = accentGradient
        self.trend = trend
    }

    public var body: some View {
        let theme = VisualTheme(colorScheme: colorScheme, highContrast: highContrastMode)
        GlassPanel(glow: false, hoverEffect: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background((accentGradient ?? theme.accentGradient), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                    if let trend, !trend.isEmpty {
                        Text(trend)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textSecondary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
