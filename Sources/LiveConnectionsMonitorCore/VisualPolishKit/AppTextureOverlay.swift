import SwiftUI

public enum AppTexturePattern: String, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case fineGrain = "Fine Grain"
    case dotGrid = "Dot Grid"
    case diagonalWeave = "Diagonal Weave"
    case technicalGrid = "Technical Grid"
    case circuitTraces = "Circuit Traces"

    public var id: String { rawValue }
}

public struct AppTextureOverlay: View {
    @AppStorage("visual.texturePattern") private var patternRawValue = AppTexturePattern.none.rawValue
    @AppStorage("visual.textureIntensity") private var intensity = 0.16
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let pattern = AppTexturePattern(rawValue: patternRawValue) ?? .none
        if pattern != .none {
            Canvas { context, size in
                let color = colorScheme == .dark ? Color.white : Color.black
                draw(pattern, context: &context, size: size, color: color.opacity(intensity))
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private func draw(_ pattern: AppTexturePattern, context: inout GraphicsContext, size: CGSize, color: Color) {
        switch pattern {
        case .none:
            break
        case .fineGrain:
            for y in stride(from: CGFloat(2), through: size.height, by: 7) {
                for x in stride(from: CGFloat(2), through: size.width, by: 7) {
                    let hash = Int(x * 13 + y * 29) % 17
                    guard hash < 5 else { continue }
                    context.fill(Path(ellipseIn: CGRect(x: x + CGFloat(hash % 3), y: y, width: 0.8, height: 0.8)), with: .color(color))
                }
            }
        case .dotGrid:
            for y in stride(from: CGFloat(12), through: size.height, by: 22) {
                for x in stride(from: CGFloat(12), through: size.width, by: 22) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(color))
                }
            }
        case .diagonalWeave:
            var path = Path()
            for offset in stride(from: -size.height, through: size.width, by: 18) {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
            }
            context.stroke(path, with: .color(color), lineWidth: 0.55)
        case .technicalGrid:
            var path = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: 28) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 28) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(color), lineWidth: 0.45)
        case .circuitTraces:
            var path = Path()
            for y in stride(from: CGFloat(18), through: size.height, by: 54) {
                let bend = CGFloat(Int(y) % 108 == 0 ? 34 : 68)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: bend, y: y))
                path.addLine(to: CGPoint(x: bend + 18, y: y + 18))
                path.addLine(to: CGPoint(x: min(size.width, bend + 150), y: y + 18))
            }
            context.stroke(path, with: .color(color), lineWidth: 0.8)
        }
    }
}
