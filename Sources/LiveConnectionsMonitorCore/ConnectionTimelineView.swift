import SwiftUI

public struct ConnectionTimelineView: View {
    @ObservedObject private var viewModel: ApplicationNetworkViewModel

    public init(viewModel: ApplicationNetworkViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                header
                replayControls
                metrics
                timelineTable
                footer
            }
            .padding(16)
        }
        .onAppear {
            viewModel.start()
            Task { await viewModel.reloadTimeline() }
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Connection Timeline")
                    .font(.title2.weight(.semibold))
                Text("Persistent process and endpoint metadata from the application activity recorder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("Filter process, IP, hostname, port, state…", text: $viewModel.timelineSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 330)
            Picker("Window", selection: Binding(
                get: { viewModel.timelineWindow },
                set: { viewModel.setTimelineWindow($0) }
            )) {
                ForEach(ConnectionTimelineWindow.allCases) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .frame(width: 170)
            Menu {
                Picker("Maximum displayed records", selection: $viewModel.timelineDisplayLimit) {
                    ForEach([1_000, 5_000, 10_000, 25_000], id: \.self) { limit in
                        Text(limit.formatted()).tag(limit)
                    }
                }
            } label: {
                Label("Retention", systemImage: "externaldrive")
            }
            Button {
                Task { await viewModel.refreshNow() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshing)
        }
    }

    private var replayControls: some View {
        GlassCard {
            HStack(spacing: 12) {
                Label("Flight Recorder", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)
                Button { viewModel.moveReplay(by: -60) } label: {
                    Label("Back 1m", systemImage: "gobackward.60")
                }
                .disabled(viewModel.timelineDateRange == nil)
                Slider(value: replayProgress, in: 0...1)
                    .disabled(viewModel.timelineDateRange == nil)
                Button { viewModel.moveReplay(by: 60) } label: {
                    Label("Forward 1m", systemImage: "goforward.60")
                }
                .disabled(viewModel.timelineDateRange == nil)
                if let replayDate = viewModel.timelineReplayDate {
                    Text(replayDate.formatted(date: .abbreviated, time: .standard))
                        .font(.callout.monospacedDigit())
                    Button("Return to Live") { viewModel.timelineReplayDate = nil }
                        .buttonStyle(.borderedProminent)
                } else {
                    Label("Live", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var replayProgress: Binding<Double> {
        Binding(
            get: {
                guard let range = viewModel.timelineDateRange else { return 1 }
                let span = range.upperBound.timeIntervalSince(range.lowerBound)
                guard span > 0 else { return 1 }
                let date = viewModel.timelineReplayDate ?? range.upperBound
                return min(1, max(0, date.timeIntervalSince(range.lowerBound) / span))
            },
            set: { value in
                guard let range = viewModel.timelineDateRange else { return }
                let span = range.upperBound.timeIntervalSince(range.lowerBound)
                viewModel.timelineReplayDate = range.lowerBound.addingTimeInterval(span * value)
            }
        )
    }

    private var metrics: some View {
        let records = viewModel.filteredTimelineConnections
        let apps = Set(records.map(\.appBundleIdentifier)).count
        let remotes = Set(records.compactMap(\.remoteAddress)).count
        let countries = Set(records.compactMap(\.countryCode)).count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            GlassMetricCard("Visible records", value: records.count.formatted(), systemImage: "list.bullet.rectangle", accent: .cyan)
            GlassMetricCard("Processes", value: apps.formatted(), systemImage: "app.connected.to.app.below.fill", accent: .blue)
            GlassMetricCard("Remote IPs", value: remotes.formatted(), systemImage: "network", accent: .orange)
            GlassMetricCard("Countries", value: countries.formatted(), systemImage: "globe", accent: .green)
        }
    }

    private var timelineTable: some View {
        Table(viewModel.filteredTimelineConnections) {
            TableColumn("Time") { record in
                Text(record.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption.monospacedDigit())
            }
            .width(min: 150, ideal: 175)
            TableColumn("Process") { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.appBundleIdentifier).lineLimit(1)
                    Text("PID \(record.pid)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 210)
            TableColumn("Direction") { record in Text(record.direction.rawValue.capitalized) }
                .width(80)
            TableColumn("Protocol") { record in Text(record.protocolKind.rawValue.uppercased()) }
                .width(70)
            TableColumn("Local") { record in
                Text(endpoint(record.localAddress, record.localPort)).font(.caption.monospaced())
            }
            .width(min: 140, ideal: 185)
            TableColumn("Remote") { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint(record.remoteAddress ?? "-", record.remotePort ?? ""))
                        .font(.caption.monospaced())
                    if let hostname = record.remoteHostname, !hostname.isEmpty {
                        Text(hostname).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .width(min: 150, ideal: 220)
            TableColumn("Country") { record in Text(record.countryCode ?? "-") }
                .width(65)
            TableColumn("State") { record in Text(record.state) }
                .width(min: 80, ideal: 105)
            TableColumn("Rule") { record in Text(record.ruleAction.label) }
                .width(min: 85, ideal: 110)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        HStack {
            Text("Stores endpoint and process metadata only; no packet payloads are captured.")
            Spacer()
            if let oldest = viewModel.timelineHistory.last?.timestamp,
               let newest = viewModel.timelineHistory.first?.timestamp {
                Text("Retained view: \(oldest.formatted(date: .abbreviated, time: .shortened)) – \(newest.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func endpoint(_ address: String, _ port: String) -> String {
        port.isEmpty ? address : "\(address):\(port)"
    }
}
