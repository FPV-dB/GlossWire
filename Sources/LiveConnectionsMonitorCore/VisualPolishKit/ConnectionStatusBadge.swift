import SwiftUI

public enum PrettyConnectionStatus: String, CaseIterable, Sendable {
    case established = "Established"
    case listening = "Listening"
    case closing = "Closing"
    case closed = "Closed"
    case blocked = "Blocked"
    case unknown = "Unknown"

    public var color: Color {
        switch self {
        case .established: .green
        case .listening: .cyan
        case .closing: .orange
        case .closed: .secondary
        case .blocked: .red
        case .unknown: .gray
        }
    }
}

public struct ConnectionStatusBadge: View {
    let status: PrettyConnectionStatus

    public init(_ status: PrettyConnectionStatus) {
        self.status = status
    }

    public var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(status.color.opacity(0.28), lineWidth: 1))
    }
}
