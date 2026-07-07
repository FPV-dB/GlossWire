import SwiftUI

public struct AppVisualSettings {
    @AppStorage("visual.enableGradientBackground") public var enableGradientBackground = true
    @AppStorage("visual.enableGlassPanels") public var enableGlassPanels = true
    @AppStorage("visual.enableRowHoverGlow") public var enableRowHoverGlow = true
    @AppStorage("visual.enableTrafficSparklines") public var enableTrafficSparklines = true
    @AppStorage("visual.compactMode") public var compactMode = false
    @AppStorage("visual.reduceAnimations") public var reduceAnimations = false
    @AppStorage("visual.highContrastMode") public var highContrastMode = false

    public init() {}
}
