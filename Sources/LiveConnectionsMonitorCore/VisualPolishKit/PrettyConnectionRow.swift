import AppKit
import SwiftUI

public struct PrettyConnectionRow<ContextMenuContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("visual.enableRowHoverGlow") private var enableHoverGlow = true
    @AppStorage("visual.enableTrafficSparklines") private var enableSparklines = true
    @AppStorage("visual.compactMode") private var compactMode = false
    @AppStorage("visual.highContrastMode") private var highContrastMode = false
    @State private var hovering = false

    private let processName: String
    private let appIcon: NSImage?
    private let remoteIP: String
    private let hostname: String?
    private let countryRegion: String?
    private let proto: String
    private let port: String
    private let direction: String
    private let status: PrettyConnectionStatus
    private let trafficAmount: String
    private let risk: ConnectionRiskLevel
    private let trafficHistory: [Double]
    private let selected: Bool
    private let contextMenuContent: ContextMenuContent

    public init(
        processName: String,
        appIcon: NSImage? = nil,
        remoteIP: String,
        hostname: String? = nil,
        countryRegion: String? = nil,
        proto: String,
        port: String,
        direction: String,
        status: PrettyConnectionStatus,
        trafficAmount: String,
        risk: ConnectionRiskLevel,
        trafficHistory: [Double] = [],
        selected: Bool = false,
        @ViewBuilder contextMenu: () -> ContextMenuContent
    ) {
        self.processName = processName
        self.appIcon = appIcon
        self.remoteIP = remoteIP
        self.hostname = hostname
        self.countryRegion = countryRegion
        self.proto = proto
        self.port = port
        self.direction = direction
        self.status = status
        self.trafficAmount = trafficAmount
        self.risk = risk
        self.trafficHistory = trafficHistory
        self.selected = selected
        self.contextMenuContent = contextMenu()
    }

    public var body: some View {
        let theme = VisualTheme(colorScheme: colorScheme, highContrast: highContrastMode)
        HStack(spacing: compactMode ? 8 : 12) {
            status.color
                .frame(width: 4)
                .clipShape(Capsule())
            iconView
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(processName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(direction.capitalized)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: 8) {
                    Text(remoteIP)
                        .font(.system(.callout, design: .monospaced))
                    if let hostname, !hostname.isEmpty {
                        Text(hostname).foregroundStyle(theme.textSecondary)
                    }
                    if let countryRegion, !countryRegion.isEmpty {
                        Text(countryRegion).foregroundStyle(theme.textSecondary)
                    }
                }
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    Text(proto)
                    Text(port.isEmpty ? "-" : port)
                        .font(.system(.caption, design: .monospaced))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                Text(trafficAmount)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            if enableSparklines && !trafficHistory.isEmpty {
                TrafficSparklineView(values: trafficHistory, lineColor: status.color)
                    .frame(width: 74, height: 28)
            }
            VStack(alignment: .trailing, spacing: 5) {
                ConnectionStatusBadge(status)
                RiskBadge(risk)
            }
        }
        .padding(.horizontal, compactMode ? 8 : 12)
        .padding(.vertical, compactMode ? 7 : 10)
        .background(rowBackground(theme: theme))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? status.color.opacity(0.55) : theme.borderSubtle, lineWidth: selected ? 1.4 : 1)
        )
        .shadow(color: hovering && enableHoverGlow ? status.color.opacity(0.18) : .clear, radius: 10, x: 0, y: 5)
        .contentShape(Rectangle())
        .contextMenu { contextMenuContent }
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
    }

    @ViewBuilder
    private var iconView: some View {
        if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            Image(systemName: "app.dashed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .frame(width: 30, height: 30)
                .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func rowBackground(theme: VisualTheme) -> some ShapeStyle {
        if selected {
            return AnyShapeStyle(status.color.opacity(colorScheme == .dark ? 0.18 : 0.12))
        }
        if hovering {
            return AnyShapeStyle(status.color.opacity(colorScheme == .dark ? 0.10 : 0.07))
        }
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.34 : 0.70))
    }
}
