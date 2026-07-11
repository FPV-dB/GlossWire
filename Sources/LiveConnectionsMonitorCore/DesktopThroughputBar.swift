import AppKit
import Combine
import SwiftUI

@MainActor
public final class DesktopThroughputBarController: ObservableObject {
    public static let enabledDefaultsKey = "desktopThroughputBar.enabled"

    private let monitor: NetworkThroughputMonitor
    private var panel: NSPanel?
    private var defaultsObserver: NSObjectProtocol?
    private var lastEnabledState: Bool?

    public init(monitor: NetworkThroughputMonitor) {
        self.monitor = monitor
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.synchronizeVisibility() }
        }
    }

    public func start() {
        synchronizeVisibility()
    }

    public func synchronizeVisibility() {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        guard enabled != lastEnabledState else { return }
        lastEnabledState = enabled
        if enabled {
            show()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func show() {
        let panel = panel ?? makePanel()
        if !panel.setFrameUsingName("DesktopThroughputBarFrame") {
            positionAtTopRight(panel)
        }
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 96),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.setFrameAutosaveName("DesktopThroughputBarFrame")
        panel.contentView = DraggableHostingView(rootView: DesktopThroughputBarView(monitor: monitor))
        self.panel = panel
        return panel
    }

    private func positionAtTopRight(_ panel: NSPanel) {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.maxY - panel.frame.height - 24)
        panel.setFrameOrigin(origin)
    }
}

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

public struct DesktopThroughputBarView: View {
    @ObservedObject private var monitor: NetworkThroughputMonitor
    @State private var hovering = false
    @AppStorage("desktopThroughputBar.opacity") private var barOpacity = 0.88

    public init(monitor: NetworkThroughputMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: 7) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                Text("LIVE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 42)

            throughputMetric("Download", icon: "arrow.down", value: download, color: .cyan)
            throughputMetric("Upload", icon: "arrow.up", value: upload, color: .green)

            TrafficSparkline(history: monitor.history, showFill: false)
                .frame(width: 112, height: 38)
                .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            if hovering {
                Button {
                    UserDefaults.standard.set(false, forKey: DesktopThroughputBarController.enabledDefaultsKey)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide desktop throughput bar")
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 480, height: 88)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .opacity(barOpacity)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onHover { hovering = $0 }
        .help("Drag to reposition")
    }

    private func throughputMetric(_ title: String, icon: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 88, alignment: .leading)
        }
    }

    private var download: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.current.downloadBytesPerSecond, unit: monitor.rateUnit)
    }

    private var upload: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.current.uploadBytesPerSecond, unit: monitor.rateUnit)
    }
}
