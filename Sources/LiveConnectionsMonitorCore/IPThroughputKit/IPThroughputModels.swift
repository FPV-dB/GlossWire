import Foundation

public struct ThroughputSample: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var timestamp: Date
    public var ipAddress: String
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var bytesTotal: UInt64
    public var bitsPerSecondIn: Double
    public var bitsPerSecondOut: Double
    public var bitsPerSecondTotal: Double
}

public struct IPThroughputSeries: Codable, Hashable, Sendable {
    public var ipAddress: String
    public var samples: [ThroughputSample]
    public var currentInBps: Double
    public var currentOutBps: Double
    public var currentTotalBps: Double
    public var peakInBps: Double
    public var peakOutBps: Double
    public var peakTotalBps: Double
    public var averageInBps: Double
    public var averageOutBps: Double
    public var averageTotalBps: Double

    public static func empty(ipAddress: String = "") -> IPThroughputSeries {
        IPThroughputSeries(
            ipAddress: ipAddress,
            samples: [],
            currentInBps: 0,
            currentOutBps: 0,
            currentTotalBps: 0,
            peakInBps: 0,
            peakOutBps: 0,
            peakTotalBps: 0,
            averageInBps: 0,
            averageOutBps: 0,
            averageTotalBps: 0
        )
    }
}

public enum IPThroughputSamplingInterval: Int, CaseIterable, Identifiable, Codable, Sendable {
    case ms250 = 250
    case ms500 = 500
    case s1 = 1_000
    case s2 = 2_000
    case s5 = 5_000
    case s10 = 10_000
    case s30 = 30_000
    case s60 = 60_000

    public var id: Int { rawValue }
    public var label: String {
        rawValue < 1_000 ? "\(rawValue) ms" : "\(rawValue / 1_000) second\(rawValue == 1_000 ? "" : "s")"
    }
}

public enum IPThroughputTimeWindow: String, CaseIterable, Identifiable, Codable, Sendable {
    case seconds30 = "Last 30 seconds"
    case minute1 = "Last 1 minute"
    case minutes5 = "Last 5 minutes"
    case minutes15 = "Last 15 minutes"
    case hour1 = "Last 1 hour"
    case custom = "Custom"

    public var id: String { rawValue }
    public var seconds: TimeInterval? {
        switch self {
        case .seconds30: 30
        case .minute1: 60
        case .minutes5: 300
        case .minutes15: 900
        case .hour1: 3_600
        case .custom: nil
        }
    }
}

public struct IPThroughputSettings: Sendable {
    public var enabled: Bool
    public var defaultSamplingIntervalMs: Int
    public var defaultTimeWindow: IPThroughputTimeWindow
    public var showUploadLine: Bool
    public var showDownloadLine: Bool
    public var showTotalLine: Bool
    public var keepHistoryAfterDeselection: Bool
    public var maximumSamplesPerIP: Int
    public var enableCSVExport: Bool
    public var customTimeWindowSeconds: TimeInterval
}
