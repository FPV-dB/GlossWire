import SwiftUI

public struct VisualTheme {
    public let colorScheme: ColorScheme
    public let highContrast: Bool

    public init(colorScheme: ColorScheme, highContrast: Bool = false) {
        self.colorScheme = colorScheme
        self.highContrast = highContrast
    }

    public var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.027, blue: 0.045),
                    Color(red: 0.045, green: 0.052, blue: 0.090),
                    Color(red: 0.025, green: 0.030, blue: 0.050)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1.0),
                    Color(red: 0.985, green: 0.975, blue: 1.0),
                    Color(red: 0.96, green: 0.98, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    public var panelGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.13), Color.white.opacity(0.035)]
                : [Color.white.opacity(0.72), Color.white.opacity(0.36)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var accentGradient: LinearGradient {
        LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var dangerGradient: LinearGradient {
        LinearGradient(colors: [Color.red, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var warningGradient: LinearGradient {
        LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var successGradient: LinearGradient {
        LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var inactiveGradient: LinearGradient {
        LinearGradient(colors: [Color.gray.opacity(0.75), Color.secondary.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public var textPrimary: Color {
        highContrast ? .primary : (colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.86))
    }

    public var textSecondary: Color {
        highContrast ? .secondary : .secondary.opacity(colorScheme == .dark ? 0.86 : 0.78)
    }

    public var borderSubtle: Color {
        highContrast ? .primary.opacity(0.30) : (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10))
    }

    public var glowAccent: Color {
        colorScheme == .dark ? .cyan.opacity(0.22) : .blue.opacity(0.14)
    }

    public var shadowSoft: Color {
        colorScheme == .dark ? .black.opacity(0.32) : .black.opacity(0.10)
    }
}
