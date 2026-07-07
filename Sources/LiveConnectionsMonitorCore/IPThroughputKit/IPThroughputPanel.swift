import SwiftUI

public struct IPThroughputPanel: View {
    @ObservedObject var viewModel: IPThroughputViewModel

    public init(viewModel: IPThroughputViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView("Throughput", subtitle: viewModel.selectedIP ?? "Select an IP address to view live throughput.", systemImage: "waveform.path.ecg")
                if viewModel.selectedIP == nil {
                    ContentUnavailableView(
                        "Select an IP address to view live throughput.",
                        systemImage: "waveform.path.ecg",
                        description: Text("Upload, download, and total speed will appear here when traffic is observed.")
                    )
                    .frame(minHeight: 260)
                } else {
                    metrics
                    ThroughputGraphView(
                        samples: viewModel.series.samples,
                        showUpload: viewModel.showUploadLine,
                        showDownload: viewModel.showDownloadLine,
                        showTotal: viewModel.showTotalLine
                    )
                    .frame(height: 220)
                    controls
                }
            }
        }
        .padding(12)
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            metric("Download", viewModel.series.currentInBps)
            metric("Upload", viewModel.series.currentOutBps)
            metric("Total", viewModel.series.currentTotalBps)
            metric("Peak", viewModel.series.peakTotalBps)
            metric("Average", viewModel.series.averageTotalBps)
        }
    }

    private func metric(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(format(value)).font(.system(.body, design: .monospaced).weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Sampling", selection: $viewModel.samplingIntervalMs) {
                    ForEach(IPThroughputSamplingInterval.allCases) { interval in
                        Text(interval.label).tag(interval.rawValue)
                    }
                }
                TextField("Custom ms", value: Binding(
                    get: { viewModel.samplingIntervalMs },
                    set: { viewModel.samplingIntervalMs = min(60_000, max(250, $0)) }
                ), format: .number)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
                Picker("Window", selection: $viewModel.timeWindow) {
                    ForEach(IPThroughputTimeWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
            }
            HStack {
                Button(viewModel.isPaused ? "Resume" : "Pause") { viewModel.pauseResume() }
                Button("Clear Graph") {
                    if let ip = viewModel.selectedIP { viewModel.clear(ip: ip) }
                }
                Button("Export CSV") { viewModel.exportCSV() }
                    .disabled(!viewModel.enableCSVExport)
            }
        }
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
