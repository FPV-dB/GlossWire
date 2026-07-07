import SwiftUI

public struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("visual.highContrastMode") private var highContrastMode = false

    public init() {}

    public var body: some View {
        let theme = VisualTheme(colorScheme: colorScheme, highContrast: highContrastMode)
        ZStack {
            theme.backgroundGradient
            RadialGradient(
                colors: [Color.cyan.opacity(colorScheme == .dark ? 0.18 : 0.14), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 620
            )
            RadialGradient(
                colors: [Color.purple.opacity(colorScheme == .dark ? 0.13 : 0.08), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 560
            )
            RadialGradient(
                colors: [Color.blue.opacity(colorScheme == .dark ? 0.10 : 0.07), .clear],
                center: .center,
                startRadius: 80,
                endRadius: 760
            )
        }
        .ignoresSafeArea()
    }
}
