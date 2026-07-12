import SwiftUI

public struct InvestigationVisualsView: View {
    @ObservedObject private var network: ApplicationNetworkViewModel
    @StateObject private var model = InvestigationVisualsViewModel()
    @State private var mode = VisualMode.processTree

    public init(network: ApplicationNetworkViewModel) { self.network = network }

    public var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Investigation Visuals").font(.title2.weight(.semibold))
                        Text("Process hierarchy and retained process-to-destination relationships.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("View", selection: $mode) { ForEach(VisualMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 300)
                    Button("Refresh") { Task { await refresh() } }
                }
                if mode == .processTree { processTree } else { sankey }
                Text("Visuals use retained endpoint metadata. The process tree reflects the current macOS process table; historical parents that have exited may be unavailable.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .task { await refresh() }
    }

    private func refresh() async {
        network.start()
        network.setTimelineWindow(.all)
        await network.reloadTimeline()
        await model.refresh()
    }

    private var processTree: some View {
        let rows = InvestigationVisualAnalyzer().processNodes(processes: model.processes, records: network.timelineHistory)
        return List(rows) { row in
            HStack {
                Text(String(repeating: "    ", count: min(6, row.depth)) + (row.depth > 0 ? "└─ " : "") + URL(fileURLWithPath: row.process.command).lastPathComponent).font(.body.monospaced())
                Text("PID \(row.process.pid) · parent \(row.process.parentPID)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(row.connectionCount) observations · \(row.destinations) destinations").font(.caption.monospacedDigit())
            }
        }
    }

    @ViewBuilder private var sankey: some View {
        let edges = InvestigationVisualAnalyzer().flowEdges(records: network.timelineHistory)
        VStack(alignment: .leading) {
            if edges.isEmpty { ContentUnavailableView("No flow relationships", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Retained remote endpoints are required.")) }
            else { SankeyRelationshipCanvas(edges: edges).frame(minHeight: 480) }
            Text("Line thickness represents retained observation count, not measured bandwidth.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private enum VisualMode: String, CaseIterable, Identifiable { case processTree = "Process Tree", sankey = "Sankey"; var id: String { rawValue } }

private struct SankeyRelationshipCanvas: View {
    let edges: [ProcessFlowEdge]
    var body: some View {
        Canvas { context, size in
            let processes = Array(Set(edges.map(\.process))).sorted(), destinations = Array(Set(edges.map(\.destination))).sorted()
            let leftX = 150.0, rightX = max(360, size.width - 180)
            func y(_ index: Int, _ count: Int) -> Double { count <= 1 ? size.height / 2 : 30 + Double(index) * (size.height - 60) / Double(count - 1) }
            for edge in edges {
                guard let pi = processes.firstIndex(of: edge.process), let di = destinations.firstIndex(of: edge.destination) else { continue }
                let start = CGPoint(x: leftX, y: y(pi, processes.count)), end = CGPoint(x: rightX, y: y(di, destinations.count))
                var path = Path(); path.move(to: start); path.addCurve(to: end, control1: CGPoint(x: size.width * 0.42, y: start.y), control2: CGPoint(x: size.width * 0.58, y: end.y))
                context.stroke(path, with: .color(.cyan.opacity(0.42)), lineWidth: min(18, max(1, Double(edge.count).squareRoot())))
            }
            for (index, value) in processes.enumerated() { context.draw(Text(value).font(.caption), at: CGPoint(x: 8, y: y(index, processes.count)), anchor: .leading) }
            for (index, value) in destinations.enumerated() { context.draw(Text(value).font(.caption), at: CGPoint(x: size.width - 8, y: y(index, destinations.count)), anchor: .trailing) }
        }
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}
