import SwiftUI
import Darwin

public struct ThroughputMenuBarLabel: View {
    private static let stableContentWidth: CGFloat = 164
    @ObservedObject private var monitor: NetworkThroughputMonitor

    public init(monitor: NetworkThroughputMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        if monitor.displayEnabled {
            Group {
                if monitor.displayMode == .compact {
                    Text("D:\(compactDownload) U:\(compactUpload)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                } else {
                    Text("\(Image(systemName: "arrow.down")) \(download)  \(Image(systemName: "arrow.up")) \(upload)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .frame(width: Self.stableContentWidth, alignment: .leading)
        } else {
            Image(systemName: "network")
        }
    }

    private var download: String {
        ThroughputFormatter.menuBarString(
            bytesPerSecond: monitor.current.downloadBytesPerSecond,
            unit: monitor.rateUnit,
            compact: false
        )
    }

    private var upload: String {
        ThroughputFormatter.menuBarString(
            bytesPerSecond: monitor.current.uploadBytesPerSecond,
            unit: monitor.rateUnit,
            compact: false
        )
    }

    private var compactDownload: String {
        ThroughputFormatter.menuBarString(
            bytesPerSecond: monitor.current.downloadBytesPerSecond,
            unit: monitor.rateUnit,
            compact: true
        )
    }

    private var compactUpload: String {
        ThroughputFormatter.menuBarString(
            bytesPerSecond: monitor.current.uploadBytesPerSecond,
            unit: monitor.rateUnit,
            compact: true
        )
    }
}

public struct NetworkThroughputPopover: View {
    @ObservedObject private var monitor: NetworkThroughputMonitor
    private let activeConnections: Int
    private let newConnectionsLastMinute: Int
    private let recentAlerts: Int
    private let showConnections: () -> Void
    private let refreshConnections: () -> Void
    private let quit: () -> Void

    public init(
        monitor: NetworkThroughputMonitor,
        activeConnections: Int = 0,
        newConnectionsLastMinute: Int = 0,
        recentAlerts: Int = 0,
        showConnections: @escaping () -> Void,
        refreshConnections: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.activeConnections = activeConnections
        self.newConnectionsLastMinute = newConnectionsLastMinute
        self.recentAlerts = recentAlerts
        self.showConnections = showConnections
        self.refreshConnections = refreshConnections
        self.quit = quit
    }

    public var body: some View {
        ZStack {
            AppBackground()
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Network Throughput", systemImage: "network")
                            .font(.headline)
                        Spacer()
                        StatusPill("Live", kind: .open)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        metricRow("Download", systemImage: "arrow.down", value: currentDownload, color: .cyan)
                        metricRow("Upload", systemImage: "arrow.up", value: currentUpload, color: .green)
                        Divider().gridCellColumns(3)
                        metricRow("Peak download", systemImage: "arrow.down.to.line", value: peakDownload, color: .cyan)
                        metricRow("Peak upload", systemImage: "arrow.up.to.line", value: peakUpload, color: .green)
                    }

                    TrafficSparkline(history: monitor.history)
                        .frame(height: 82)
                        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .topLeading) {
                            Text("Last 60 seconds")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(6)
                        }

                    miniDashboard

                    milestoneProgress

                    HStack {
                        Button("Show Connections", action: showConnections)
                            .buttonStyle(.borderedProminent)
                        Button {
                            refreshConnections()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .help("Refresh connections")
                        Spacer()
                        Button("Quit", action: quit)
                    }
                }
            }
        }
        .frame(width: 350)
    }

    private var miniDashboard: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                miniMetric("Active", value: activeConnections.formatted(), icon: "network", color: .cyan)
                miniMetric("New / min", value: newConnectionsLastMinute.formatted(), icon: "plus.circle", color: .green)
            }
            GridRow {
                miniMetric("Alerts / hr", value: recentAlerts.formatted(), icon: "exclamationmark.triangle", color: recentAlerts > 0 ? .orange : .secondary)
                miniMetric("Memory", value: Self.memoryFootprint, icon: "memorychip", color: .purple)
            }
            GridRow {
                miniMetric("System load", value: Self.systemLoad, icon: "cpu", color: .blue)
                miniMetric("Internet latency", value: "Not sampled", icon: "timer", color: .secondary)
            }
        }
        .padding(9)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
    }

    private func miniMetric(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.monospacedDigit()).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private static var memoryFootprint: String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return "Unavailable" }
        return ByteCountFormatter.string(fromByteCount: Int64(info.resident_size), countStyle: .memory)
    }

    private static var systemLoad: String {
        var values = [Double](repeating: 0, count: 1)
        guard getloadavg(&values, 1) == 1 else { return "Unavailable" }
        return String(format: "%.2f", values[0])
    }

    private func metricRow(_ title: String, systemImage: String, value: String, color: Color) -> some View {
        GridRow {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var currentDownload: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.current.downloadBytesPerSecond, unit: monitor.rateUnit)
    }

    private var currentUpload: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.current.uploadBytesPerSecond, unit: monitor.rateUnit)
    }

    private var peakDownload: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.peakDownloadBytesPerSecond, unit: monitor.rateUnit)
    }

    private var peakUpload: String {
        ThroughputFormatter.string(bytesPerSecond: monitor.peakUploadBytesPerSecond, unit: monitor.rateUnit)
    }

    @ViewBuilder
    private var milestoneProgress: some View {
        let manager = monitor.dataMilestoneSoundManager
        if manager.enabled {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("Data Milestone Sounds", systemImage: "speaker.wave.2")
                        .font(.caption)
                    Spacer()
                    Text(manager.direction.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: milestoneFraction)
                Text(manager.progressDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var milestoneFraction: Double {
        let manager = monitor.dataMilestoneSoundManager
        guard manager.thresholdBytes > 0 else { return 0 }
        return min(1, max(0, Double(manager.currentIntervalBytes) / Double(manager.thresholdBytes)))
    }
}

private struct ThroughputGraph: View {
    let history: [NetworkThroughputHistoryPoint]

    var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            let maximum = max(
                history.map { $0.reading.downloadBytesPerSecond }.max() ?? 0,
                history.map { $0.reading.uploadBytesPerSecond }.max() ?? 0,
                1
            )
            draw(\.reading.downloadBytesPerSecond, color: .blue, maximum: maximum, context: &context, size: size)
            draw(\.reading.uploadBytesPerSecond, color: .green, maximum: maximum, context: &context, size: size)
        }
        .padding(.horizontal, 5)
        .padding(.top, 18)
        .padding(.bottom, 5)
    }

    private func draw(
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
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
