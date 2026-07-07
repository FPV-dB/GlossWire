import SwiftUI

public struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    public init(_ title: String, subtitle: String = "", systemImage: String = "circle.grid.cross") {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(width: 30, height: 30)
                .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
