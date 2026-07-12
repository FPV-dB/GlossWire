import SwiftUI

public struct UnifiedAlertCenterView: View {
    @ObservedObject private var network: ApplicationNetworkViewModel
    @StateObject private var model = UnifiedAlertCenterViewModel()

    public init(network: ApplicationNetworkViewModel) { self.network = network }

    public var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 12) {
                header
                filters
                mutedProcesses
                List(model.visibleAlerts) { alert in alertRow(alert) }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(16)
        }
        .task {
            network.start()
            await network.reloadTimeline()
            await model.evaluate(records: network.timelineHistory, samples: network.samplesByApp)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Alert Centre").font(.title2.weight(.semibold))
                Text("Informational investigation signals. Alerts never block traffic automatically.").foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await model.evaluate(records: network.timelineHistory, samples: network.samplesByApp) } } label: { Label("Evaluate Now", systemImage: "waveform.badge.magnifyingglass") }
            Button { Task { await model.reload() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
    }

    private var filters: some View {
        HStack {
            Picker("Minimum", selection: $model.minimumSeverity) { ForEach(UnifiedAlertSeverity.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 150)
            Picker("Status", selection: $model.statusFilter) {
                Text("All").tag(UnifiedAlertStatus?.none)
                ForEach(UnifiedAlertStatus.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }.frame(width: 170)
            TextField("Search alerts", text: $model.search).textFieldStyle(.roundedBorder)
            Spacer()
            Text("\(model.visibleAlerts.count) visible").font(.caption.monospacedDigit())
        }
    }

    @ViewBuilder private var mutedProcesses: some View {
        if !model.mutes.isEmpty {
            ScrollView(.horizontal) {
                HStack {
                    Text("Muted:").font(.caption)
                    ForEach(model.mutes, id: \.process) { mute in
                        Button("\(mute.process) until \(mute.until.formatted(date: .omitted, time: .shortened)) ×") { model.unmute(mute.process) }.buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func alertRow(_ alert: UnifiedAlert) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                severityBadge(alert.severity)
                Text(alert.category).font(.caption)
                Text(alert.title).font(.headline)
                Spacer()
                Text(alert.updatedAt.formatted(date: .abbreviated, time: .standard)).font(.caption.monospacedDigit())
                if alert.occurrenceCount > 1 { Text("×\(alert.occurrenceCount)").font(.caption.monospacedDigit()) }
            }
            Text(alert.detail).font(.callout)
            if let process = alert.process {
                HStack { Text(process).font(.caption.monospaced()); Button("Mute 24h") { model.mute(process) }.buttonStyle(.borderless) }
            }
            HStack {
                Text(alert.status.rawValue).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if alert.status == .open { Button("Acknowledge") { model.setStatus(alert, .acknowledged) } }
                if alert.status != .resolved { Button("Resolve") { model.setStatus(alert, .resolved) } }
            }
        }
        .padding(.vertical, 4)
    }

    private func severityBadge(_ severity: UnifiedAlertSeverity) -> some View {
        Text(severity.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3)
            .background(color(severity).opacity(0.18), in: Capsule()).foregroundStyle(color(severity))
    }

    private func color(_ severity: UnifiedAlertSeverity) -> Color {
        switch severity { case .info: .blue; case .notice: .cyan; case .warning: .orange; case .critical: .red }
    }
}
