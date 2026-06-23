import AppKit
import SwiftUI

public struct AppBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.035, blue: 0.055),
                    Color(red: 0.055, green: 0.065, blue: 0.105),
                    Color(red: 0.030, green: 0.034, blue: 0.052)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.cyan.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 620
            )
            RadialGradient(
                colors: [Color.blue.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }
}

public struct GlassCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.72))
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.cyan.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}

public struct GlassMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    public init(_ title: String, value: String, systemImage: String, accent: Color = .cyan) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.accent = accent
    }

    public var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 30, height: 30)
                        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                    Spacer()
                    Circle()
                        .fill(accent.opacity(0.75))
                        .frame(width: 5, height: 5)
                        .shadow(color: accent.opacity(0.8), radius: 5)
                }
                Text(value)
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct StatusPill: View {
    public enum Kind {
        case open
        case blocked
        case allowlisted
        case neutral
        case warning

        var color: Color {
            switch self {
            case .open: .cyan
            case .blocked: .red
            case .allowlisted: .green
            case .neutral: .secondary
            case .warning: .orange
            }
        }
    }

    let text: String
    let kind: Kind

    public init(_ text: String, kind: Kind = .neutral) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(kind.color)
            .background(kind.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(kind.color.opacity(0.28), lineWidth: 1))
    }
}

public struct TrafficSparkline: View {
    let history: [NetworkThroughputHistoryPoint]
    let showFill: Bool

    public init(history: [NetworkThroughputHistoryPoint], showFill: Bool = true) {
        self.history = history
        self.showFill = showFill
    }

    public var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            let maximum = max(
                history.map { $0.reading.downloadBytesPerSecond }.max() ?? 0,
                history.map { $0.reading.uploadBytesPerSecond }.max() ?? 0,
                1
            )
            drawLine(\.reading.downloadBytesPerSecond, color: .cyan, maximum: maximum, context: &context, size: size)
            drawLine(\.reading.uploadBytesPerSecond, color: .green, maximum: maximum, context: &context, size: size)
        }
    }

    private func drawLine(
        _ keyPath: KeyPath<NetworkThroughputHistoryPoint, Double>,
        color: Color,
        maximum: Double,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        var path = Path()
        for (index, point) in history.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(max(1, history.count - 1))
            let ratio = min(1, max(0, point[keyPath: keyPath] / maximum))
            let y = size.height * (1 - CGFloat(ratio))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color.opacity(0.95)), lineWidth: 2.2)

        if showFill {
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(0.18), color.opacity(0.015)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}

public struct ProcessIconLabel: View {
    let processName: String
    let systemImage: String

    public init(_ processName: String, systemImage: String = "app.dashed") {
        self.processName = processName
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
                .frame(width: 24, height: 24)
                .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            Text(processName)
                .lineLimit(1)
        }
    }
}

public struct InspectorSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    public init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    public var body: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                content
            }
        }
    }
}
