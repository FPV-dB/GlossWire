import SwiftUI

public struct GlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("visual.enableGlassPanels") private var enableGlassPanels = true
    @AppStorage("visual.enableRowHoverGlow") private var enableHoverGlow = true
    @AppStorage("visual.highContrastMode") private var highContrastMode = false
    @State private var isHovering = false

    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let glow: Bool
    private let hoverEffect: Bool
    private let content: Content

    public init(cornerRadius: CGFloat = 16, padding: CGFloat = 14, glow: Bool = false, hoverEffect: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.glow = glow
        self.hoverEffect = hoverEffect
        self.content = content()
    }

    public var body: some View {
        let theme = VisualTheme(colorScheme: colorScheme, highContrast: highContrastMode)
        content
            .padding(padding)
            .background(panelBackground(theme: theme))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: highContrastMode ? 1.3 : 1)
            )
            .shadow(color: glow || (hoverEffect && isHovering && enableHoverGlow) ? theme.glowAccent : theme.shadowSoft, radius: glow || isHovering ? 18 : 10, x: 0, y: 8)
            .scaleEffect(hoverEffect && isHovering && !reduceMotion ? 1.006 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovering)
            .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private func panelBackground(theme: VisualTheme) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(enableGlassPanels ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
            .overlay(theme.panelGradient.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }
}
