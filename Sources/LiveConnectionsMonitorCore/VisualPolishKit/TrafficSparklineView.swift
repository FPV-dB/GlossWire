import SwiftUI

public struct TrafficSparklineView: View {
    private let values: [Double]
    private let lineColor: Color

    public init(values: [Double], lineColor: Color = .cyan) {
        self.values = values
        self.lineColor = lineColor
    }

    public var body: some View {
        Canvas { context, size in
            guard values.count > 1, size.width > 0, size.height > 0 else { return }
            let maxValue = max(values.max() ?? 0, 1)
            let minValue = min(values.min() ?? 0, 0)
            let span = max(maxValue - minValue, 1)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let ratio = (value - minValue) / span
                let y = size.height * (1 - CGFloat(ratio))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(lineColor.opacity(0.95)), lineWidth: 1.6)
        }
        .accessibilityHidden(true)
    }
}
