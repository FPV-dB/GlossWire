import SwiftUI

public struct NmapResultsView: View {
    @ObservedObject var viewModel: NmapScanViewModel

    public init(viewModel: NmapScanViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let parsedSummary = viewModel.parsedSummary {
                NmapSummaryView(summary: parsedSummary)
            }
            TextEditor(text: .constant(viewModel.output.isEmpty ? "No output yet." : viewModel.output))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            controls
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var header: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Target IP").foregroundStyle(.secondary)
                Text(viewModel.targetIP.isEmpty ? "-" : viewModel.targetIP)
                    .font(.system(.body, design: .monospaced))
            }
            GridRow {
                Text("Status").foregroundStyle(.secondary)
                Text(viewModel.status.rawValue)
            }
            GridRow {
                Text("Command").foregroundStyle(.secondary)
                Text(viewModel.commandPreview.isEmpty ? "-" : viewModel.commandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            GridRow {
                Text("Start").foregroundStyle(.secondary)
                Text(viewModel.startTime.map(Self.dateFormatter.string(from:)) ?? "-")
            }
            GridRow {
                Text("End").foregroundStyle(.secondary)
                Text(viewModel.endTime.map(Self.dateFormatter.string(from:)) ?? "-")
            }
            GridRow {
                Text("Duration").foregroundStyle(.secondary)
                Text(viewModel.durationText)
            }
            GridRow {
                Text("Exit").foregroundStyle(.secondary)
                Text(viewModel.exitCode.map(String.init) ?? "-")
            }
        }
    }

    private var controls: some View {
        HStack {
            if viewModel.status == .running {
                Button("Cancel", role: .destructive) {
                    viewModel.cancel()
                }
            }
            Spacer()
            Button("Save Results") {
                viewModel.saveResults()
            }
            .disabled(viewModel.output.isEmpty)
            Menu("Export") {
                ForEach(NmapExportFormat.allCases) { format in
                    Button(format.rawValue) {
                        viewModel.exportResults(format: format)
                    }
                }
            }
            .disabled(viewModel.output.isEmpty)
            Button("Copy Results") {
                viewModel.copyResults()
            }
            .disabled(viewModel.output.isEmpty)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

private struct NmapSummaryView: View {
    let summary: NmapParsedSummary

    var body: some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 8) {
                if let hostStatus = summary.hostStatus {
                    Text("Host: \(hostStatus)")
                }
                if let hostname = summary.hostname {
                    Text("Hostname: \(hostname)")
                }
                if let mac = summary.macAddress {
                    Text("MAC: \(mac)")
                }
                if let vendor = summary.vendor {
                    Text("Vendor: \(vendor)")
                }
                if let os = summary.osFingerprint {
                    Text("OS: \(os)")
                }
                if let rtt = summary.rtt {
                    Text("RTT: \(rtt)")
                }
                if !summary.openPorts.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Port").bold()
                            Text("Service").bold()
                            Text("Version").bold()
                        }
                        ForEach(summary.openPorts) { port in
                            GridRow {
                                Text("\(port.port)/\(port.protocolName)").font(.system(.body, design: .monospaced))
                                Text(port.service)
                                Text(port.version.isEmpty ? "-" : port.version)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct NmapHistoryView: View {
    @ObservedObject var viewModel: NmapScanViewModel

    public init(viewModel: NmapScanViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nmap Scan History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Button("Refresh") { Task { await viewModel.loadHistory() } }
                Button("Clear", role: .destructive) { viewModel.clearHistory() }
            }

            List(viewModel.history) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.targetIP)
                            .font(.system(.body, design: .monospaced))
                        Text(item.presetName)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Self.dateFormatter.string(from: item.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text((["nmap"] + item.commandArguments).joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    if let summary = item.parsedSummary, !summary.openPorts.isEmpty {
                        Text(summary.openPorts.map { "\($0.port)/\($0.protocolName) \($0.service)" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 480)
        .task { await viewModel.loadHistory() }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
