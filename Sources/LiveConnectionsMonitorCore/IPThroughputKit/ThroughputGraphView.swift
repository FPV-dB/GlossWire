import SwiftUI

public struct ThroughputGraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    let samples: [ThroughputSample]
    let showUpload: Bool
    let showDownload: Bool
    let showTotal: Bool
    @State private var hoverLocation: CGPoint?

    public init(samples: [ThroughputSample], showUpload: Bool, showDownload: Bool, showTotal: Bool) {
        self.samples = samples
        self.showUpload = showUpload
        self.showDownload = showDownload
        self.showTotal = showTotal
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                draw(context: &context, size: size)
            }
            .overlay(alignment: .bottomLeading) {
                Text(xAxisLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .overlay(alignment: .topTrailing) {
                Text(maxLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { hoverLocation = $0.location }.onEnded { _ in hoverLocation = nil })

            if let tooltip = tooltipText {
                Text(tooltip)
                    .font(.caption)
                    .padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.28 : 0.65), in: RoundedRectangle(cornerRadius: 10))
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        guard samples.count > 1 else {
            context.draw(Text("No throughput samples yet").foregroundColor(.secondary), at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }
        let maximum = max(samples.map(\.bitsPerSecondTotal).max() ?? 0, 1)
        drawGrid(context: &context, size: size)
        if showDownload { drawLine(values: samples.map(\.bitsPerSecondIn), color: .cyan, maximum: maximum, context: &context, size: size) }
        if showUpload { drawLine(values: samples.map(\.bitsPerSecondOut), color: .green, maximum: maximum, context: &context, size: size) }
        if showTotal { drawLine(values: samples.map(\.bitsPerSecondTotal), color: .orange, maximum: maximum, context: &context, size: size) }
        if let hoverLocation {
            var path = Path()
            path.move(to: CGPoint(x: hoverLocation.x, y: 0))
            path.addLine(to: CGPoint(x: hoverLocation.x, y: size.height))
            context.stroke(path, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for index in 0...4 {
            let y = size.height * CGFloat(index) / 4
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(.secondary.opacity(0.16)), lineWidth: 1)
    }

    private func drawLine(values: [Double], color: Color, maximum: Double, context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let y = size.height * (1 - CGFloat(min(max(value / maximum, 0), 1)))
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
    }

    private var maxLabel: String {
        format(samples.map(\.bitsPerSecondTotal).max() ?? 0)
    }

    private var xAxisLabel: String {
        guard let first = samples.first?.timestamp, let last = samples.last?.timestamp else { return "" }
        return "\(first.formatted(date: .omitted, time: .standard)) - \(last.formatted(date: .omitted, time: .standard))"
    }

    private var tooltipText: String? {
        guard let hoverLocation, samples.count > 1 else { return nil }
        let ratio = min(max(hoverLocation.x / max(1, hoverLocation.x + (300 - hoverLocation.x)), 0), 1)
        let index = min(samples.count - 1, max(0, Int(Double(samples.count - 1) * Double(ratio))))
        let sample = samples[index]
        return "\(sample.timestamp.formatted(date: .omitted, time: .standard))\nD \(format(sample.bitsPerSecondIn)) U \(format(sample.bitsPerSecondOut))"
    }

    private func format(_ bps: Double) -> String {
        let units = ["bps", "Kbps", "Mbps", "Gbps"]
        var value = max(0, bps)
        var index = 0
        while value >= 1_000, index < units.count - 1 {
            value /= 1_000
            index += 1
        }
        return String(format: value >= 10 ? "%.0f %@" : "%.1f %@", value, units[index])
    }
}
