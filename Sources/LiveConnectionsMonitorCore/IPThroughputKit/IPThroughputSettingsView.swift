import SwiftUI

public struct IPThroughputSettingsView: View {
    @AppStorage("ipThroughput.enabled") private var enabled = true
    @AppStorage("ipThroughput.defaultSamplingIntervalMs") private var defaultSamplingIntervalMs = 1_000
    @AppStorage("ipThroughput.defaultTimeWindow") private var defaultTimeWindow = IPThroughputTimeWindow.minute1.rawValue
    @AppStorage("ipThroughput.showUploadLine") private var showUploadLine = true
    @AppStorage("ipThroughput.showDownloadLine") private var showDownloadLine = true
    @AppStorage("ipThroughput.showTotalLine") private var showTotalLine = true
    @AppStorage("ipThroughput.keepHistoryAfterDeselection") private var keepHistoryAfterDeselection = false
    @AppStorage("ipThroughput.maximumSamplesPerIP") private var maximumSamplesPerIP = 2_000
    @AppStorage("ipThroughput.enableCSVExport") private var enableCSVExport = true

    public init() {}

    public var body: some View {
        Section("IP Throughput") {
            Toggle("Enable IP throughput graph", isOn: $enabled)
            Picker("Default sampling interval", selection: $defaultSamplingIntervalMs) {
                ForEach(IPThroughputSamplingInterval.allCases) { interval in
                    Text(interval.label).tag(interval.rawValue)
                }
            }
            TextField("Custom default interval ms", value: Binding(
                get: { defaultSamplingIntervalMs },
                set: { defaultSamplingIntervalMs = min(60_000, max(250, $0)) }
            ), format: .number)
            Picker("Default graph time window", selection: $defaultTimeWindow) {
                ForEach(IPThroughputTimeWindow.allCases) { window in
                    Text(window.rawValue).tag(window.rawValue)
                }
            }
            Toggle("Show upload line", isOn: $showUploadLine)
            Toggle("Show download line", isOn: $showDownloadLine)
            Toggle("Show total line", isOn: $showTotalLine)
            Toggle("Keep history after IP deselection", isOn: $keepHistoryAfterDeselection)
            Stepper("Maximum samples per IP: \(maximumSamplesPerIP)", value: $maximumSamplesPerIP, in: 100...20_000, step: 100)
            Toggle("Enable CSV export", isOn: $enableCSVExport)
        }
    }

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "ipThroughput.enabled") as? Bool ?? true
    }
}
