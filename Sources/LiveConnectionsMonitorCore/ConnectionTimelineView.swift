import AppKit
import Charts
import SwiftUI

public struct ConnectionTimelineView: View {
    @ObservedObject private var viewModel: ApplicationNetworkViewModel
    @State private var displayMode = TimelineDisplayMode.records
    @StateObject private var bookmarkStore = TimelineBookmarkStore()
    @State private var comparisonDayA = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var comparisonDayB = Date()

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
                Picker("View", selection: $displayMode) {
                    ForEach(TimelineDisplayMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(width: 460)
                Group {
                    switch displayMode {
                    case .records: timelineTable
                    case .heatmap: bandwidthHeatmap
                    case .countries: countryTimeline
                    case .lifetimes: lifetimeHistogram
                    case .relationships: relationshipView
                    case .changes: whatChangedView
                    case .topology: topologyView
                    case .compare: comparisonView
                    }
                }
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
            Toggle("Privacy Mode", isOn: $viewModel.privacyModeEnabled)
                .toggleStyle(.switch)
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
                Divider().frame(height: 22)
                if viewModel.isRecordingSession {
                    Button("Stop Recording") { viewModel.stopSessionRecording() }.tint(.red)
                    Text("\(viewModel.recordedSession.count) events").font(.caption.monospacedDigit())
                } else {
                    Button("Record Session") { viewModel.startSessionRecording() }
                }
                Button("Export Session") { exportSession() }.disabled(viewModel.recordedSession.isEmpty)
                Divider().frame(height: 22)
                Button { bookmarkStore.add(at: viewModel.timelineReplayDate ?? Date()) } label: { Label("Bookmark", systemImage: "bookmark") }
                Menu("Bookmarks") {
                    if bookmarkStore.bookmarks.isEmpty { Text("No bookmarks") }
                    ForEach(bookmarkStore.bookmarks) { bookmark in
                        Button { viewModel.timelineReplayDate = bookmark.timestamp } label: { Text("\(bookmark.title) — \(bookmark.timestamp.formatted(date: .abbreviated, time: .shortened))") }
                    }
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
                    Text(PrivacyRedactor.process(record.appBundleIdentifier, enabled: viewModel.privacyModeEnabled)).lineLimit(1)
                    Text("PID \(record.pid)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 210)
            TableColumn("Direction") { record in Text(record.direction.rawValue.capitalized) }
                .width(80)
            TableColumn("Protocol") { record in Text(record.protocolKind.rawValue.uppercased()) }
                .width(70)
            TableColumn("Local") { record in
                Text(endpoint(PrivacyRedactor.address(record.localAddress, enabled: viewModel.privacyModeEnabled), record.localPort)).font(.caption.monospaced())
            }
            .width(min: 140, ideal: 185)
            TableColumn("Remote") { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint(PrivacyRedactor.address(record.remoteAddress, enabled: viewModel.privacyModeEnabled), record.remotePort ?? ""))
                        .font(.caption.monospaced())
                    if let hostname = PrivacyRedactor.hostname(record.remoteHostname, enabled: viewModel.privacyModeEnabled) {
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

    private var bandwidthHeatmap: some View {
        let groups = Dictionary(grouping: viewModel.filteredTimelineConnections, by: \.appBundleIdentifier)
        let cells = groups.map { HeatmapCell(app: $0.key, records: $0.value) }.sorted { $0.weight > $1.weight }
        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(cells) { cell in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(PrivacyRedactor.process(cell.app, enabled: viewModel.privacyModeEnabled)).font(.headline).lineLimit(1)
                        Text("\(cell.records.count) observations").font(.caption)
                        Text(cell.totalBytes == 0 ? "Per-flow bytes unavailable" : ByteCountFormatter.string(fromByteCount: Int64(clamping: cell.totalBytes), countStyle: .binary))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    .padding(12)
                    .background(cell.color.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var countryTimeline: some View {
        let counts = Dictionary(grouping: viewModel.filteredTimelineConnections, by: { $0.countryCode ?? "Unresolved" }).mapValues(\.count)
        let rows = counts.map { CountryRow(country: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
        return Chart(rows) { row in
            BarMark(x: .value("Connections", row.count), y: .value("Country", row.country))
                .foregroundStyle(row.country == "Unresolved" ? Color.secondary : Color.cyan)
                .annotation(position: .trailing) { Text(row.count.formatted()).font(.caption.monospacedDigit()) }
        }.chartXAxisLabel("Connection observations").padding(12)
    }

    private var lifetimeHistogram: some View {
        let rows = LifetimeBucket.allCases.map { bucket in
            LifetimeRow(bucket: bucket, count: viewModel.filteredTimelineConnections.filter { bucket.contains($0.duration) }.count)
        }
        return Chart(rows) { row in
            BarMark(x: .value("Lifetime", row.bucket.rawValue), y: .value("Connections", row.count))
                .foregroundStyle(.blue.gradient)
                .annotation(position: .top) { Text(row.count.formatted()).font(.caption2.monospacedDigit()) }
        }.chartYAxisLabel("Connection observations").padding(12)
    }

    private var relationshipView: some View {
        let groups = Dictionary(grouping: viewModel.filteredTimelineConnections) { record in
            RelationshipKey(app: record.appBundleIdentifier, service: ConnectionExplanationService.serviceName(for: record.remotePort ?? record.localPort))
        }
        let rows = groups.map { RelationshipRow(key: $0.key, records: $0.value) }.sorted { $0.records.count > $1.records.count }
        return List(rows) { row in
            HStack {
                Image(systemName: "app.connected.to.app.below.fill").foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text(PrivacyRedactor.process(row.key.app, enabled: viewModel.privacyModeEnabled)).font(.headline)
                    Text("└── \(row.key.service)").font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(row.records.count) observations · \(Set(row.records.compactMap(\.remoteAddress)).count) destinations").font(.caption.monospacedDigit())
            }
        }
    }

    private var whatChangedView: some View {
        let summary = NetworkInvestigationAnalyzer().changes(records: viewModel.timelineHistory)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Changes since \(summary.currentStart.formatted(date: .omitted, time: .shortened))")
                    .font(.title3.weight(.semibold))
                changeGroup("New processes", values: summary.newProcesses, icon: "plus.app")
                changeGroup("New destinations", values: summary.newDestinations.map { PrivacyRedactor.address($0, enabled: viewModel.privacyModeEnabled) }, icon: "plus.circle")
                changeGroup("New ports", values: summary.newPorts.map { "\($0) — \(ConnectionExplanationService.serviceName(for: $0))" }, icon: "number.circle")
                changeGroup("No longer observed", values: summary.disconnectedProcesses, icon: "minus.circle")
                if let percent = summary.observationChangePercent {
                    Label("Connection observations changed \(percent >= 0 ? "+" : "")\(percent)% from the previous hour.", systemImage: percent > 0 ? "arrow.up.right" : "arrow.down.right")
                        .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("A complete previous-hour window is not yet retained.").foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }

    private func changeGroup(_ title: String, values: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon).font(.headline)
            if values.isEmpty { Text("No changes detected").foregroundStyle(.secondary) }
            else { ForEach(values.prefix(20), id: \.self) { Text("• \($0)").font(.callout.monospaced()) } }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var topologyView: some View {
        let nodes = NetworkInvestigationAnalyzer().topology(records: viewModel.timelineHistory)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("This Mac", systemImage: "desktopcomputer").font(.title3.weight(.semibold))
                Text("│").font(.title2.monospaced()).foregroundStyle(.secondary).padding(.leading, 12)
                if nodes.isEmpty {
                    ContentUnavailableView("No observed LAN devices", systemImage: "network.slash", description: Text("Topology is passive. Devices appear only after GlossWire observes a connection to a private address."))
                }
                ForEach(nodes) { node in
                    HStack(alignment: .top, spacing: 10) {
                        Text("├──").font(.body.monospaced()).foregroundStyle(.secondary)
                        Image(systemName: topologyIcon(node)).foregroundStyle(.cyan).frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.name).font(.headline)
                            Text(PrivacyRedactor.address(node.address, enabled: viewModel.privacyModeEnabled)).font(.caption.monospaced())
                            Text(node.services.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(node.observationCount) observations\nLast \(node.lastSeen.formatted(date: .omitted, time: .shortened))").font(.caption.monospacedDigit()).multilineTextAlignment(.trailing)
                    }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }

    private var comparisonView: some View {
        let calendar = Calendar.current
        let aStart = calendar.startOfDay(for: comparisonDayA), bStart = calendar.startOfDay(for: comparisonDayB)
        let aEnd = calendar.date(byAdding: .day, value: 1, to: aStart)!.addingTimeInterval(-0.001)
        let bEnd = calendar.date(byAdding: .day, value: 1, to: bStart)!.addingTimeInterval(-0.001)
        let result = NetworkInvestigationAnalyzer().compare(records: viewModel.timelineHistory, first: aStart...aEnd, second: bStart...bEnd)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { DatePicker("First day", selection: $comparisonDayA, displayedComponents: .date); DatePicker("Second day", selection: $comparisonDayB, displayedComponents: .date); Spacer() }
                Text("Compare Two Days").font(.title3.weight(.semibold))
                HStack { GlassMetricCard("First observations", value: result.firstObservations.formatted(), systemImage: "1.circle", accent: .secondary); GlassMetricCard("Second observations", value: result.secondObservations.formatted(), systemImage: "2.circle", accent: .cyan); GlassMetricCard("Change", value: result.observationChangePercent.map { "\($0 >= 0 ? "+" : "")\($0)%" } ?? "No baseline", systemImage: "arrow.left.arrow.right", accent: .orange) }
                changeGroup("New processes", values: result.newProcesses.map { PrivacyRedactor.process($0, enabled: viewModel.privacyModeEnabled) }, icon: "plus.app")
                changeGroup("New destinations", values: result.newDestinations.map { PrivacyRedactor.address($0, enabled: viewModel.privacyModeEnabled) }, icon: "plus.circle")
                changeGroup("New countries", values: result.newCountries, icon: "globe")
                changeGroup("New ports", values: result.newPorts, icon: "number.circle")
                Text("Comparison uses only records currently retained and loaded by the selected Timeline window.").font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private func topologyIcon(_ node: ObservedTopologyNode) -> String {
        let text = (node.name + node.services.joined()).lowercased()
        if text.contains("nas") || text.contains("file server") { return "externaldrive.connected.to.line.below" }
        if text.contains("bonjour") { return "appletv" }
        if text.contains("web") { return "server.rack" }
        return "network"
    }

    private func endpoint(_ address: String, _ port: String) -> String {
        port.isEmpty ? address : "\(address):\(port)"
    }

    private func exportSession() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "GlossWire-network-session.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try viewModel.exportRecordedSession(to: url) }
        catch { viewModel.errorMessage = "Could not export session: \(error.localizedDescription)" }
    }
}

private enum TimelineDisplayMode: String, CaseIterable, Identifiable { case records = "Records", heatmap = "Heatmap", countries = "Countries", lifetimes = "Lifetimes", relationships = "Relationships", changes = "What Changed?", topology = "Topology", compare = "Compare"; var id: String { rawValue } }
private struct HeatmapCell: Identifiable { let app: String; let records: [AppConnectionRecord]; var id: String { app }; var totalBytes: UInt64 { records.compactMap(\.bytesSent).reduce(0, +) + records.compactMap(\.bytesReceived).reduce(0, +) }; var weight: UInt64 { totalBytes > 0 ? totalBytes : UInt64(records.count) }; var color: Color { let up = records.compactMap(\.bytesSent).reduce(0, +); let down = records.compactMap(\.bytesReceived).reduce(0, +); return totalBytes == 0 ? .blue : up > down ? .orange : .cyan } }
private struct CountryRow: Identifiable { let country: String; let count: Int; var id: String { country } }
private enum LifetimeBucket: String, CaseIterable { case milliseconds = "<1s", seconds = "1–59s", minutes = "1–59m", hours = "1–23h", days = "1d+"; func contains(_ value: TimeInterval) -> Bool { switch self { case .milliseconds: value < 1; case .seconds: value >= 1 && value < 60; case .minutes: value >= 60 && value < 3600; case .hours: value >= 3600 && value < 86400; case .days: value >= 86400 } } }
private struct LifetimeRow: Identifiable { let bucket: LifetimeBucket; let count: Int; var id: String { bucket.rawValue } }
private struct RelationshipKey: Hashable { let app: String; let service: String }
private struct RelationshipRow: Identifiable { let key: RelationshipKey; let records: [AppConnectionRecord]; var id: String { key.app + "|" + key.service } }
