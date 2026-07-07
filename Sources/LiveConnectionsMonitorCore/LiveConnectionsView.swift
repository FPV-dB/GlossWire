import SwiftUI

public struct LiveConnectionsView: View {
    @ObservedObject private var viewModel: LiveConnectionsViewModel
    @StateObject private var nmapViewModel = NmapScanViewModel()
    @State private var showingNmapWorkbench = false
    @State private var nmapTargetIP = ""
    @StateObject private var ipSafetyViewModel = IPSafetyViewModel(settingsProvider: IPSafetySettingsView.currentSettings)
    @State private var showingIPSafetyReport = false
    @State private var ipSafetyTargetIP = ""
    @StateObject private var throughputViewModel: IPThroughputViewModel
    @ObservedObject private var reputationStore = ReputationBlockListStore.shared
    @AppStorage("visual.enableGradientBackground") private var enableGradientBackground = true
    @AppStorage("visual.enableTrafficSparklines") private var enableTrafficSparklines = true

    public init(viewModel: LiveConnectionsViewModel) {
        self.viewModel = viewModel
        _throughputViewModel = StateObject(wrappedValue: IPThroughputViewModel(connectionsProvider: { viewModel.connections }))
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                if enableGradientBackground {
                    polishedConnectionList
                } else {
                    connectionTable
                }
                Divider()
                rightInspector
                    .frame(width: 330)
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
            }
        }
        .navigationTitle("Connections")
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("Block Remote IP?", isPresented: Binding(
            get: { viewModel.pendingBlockIP != nil },
            set: { if !$0 { viewModel.pendingBlockIP = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.pendingBlockIP = nil }
            Button("Block", role: .destructive) {
                if let ip = viewModel.pendingBlockIP {
                    Task { await viewModel.confirmBlock(ip: ip) }
                }
                viewModel.pendingBlockIP = nil
            }
        } message: {
            Text("Block all traffic to and from \(viewModel.pendingBlockIP ?? "this host")? This may disrupt active network activity for that host.")
        }
        .alert("Default Gateway", isPresented: Binding(
            get: { viewModel.pendingGatewayOverrideIP != nil },
            set: { if !$0 { viewModel.pendingGatewayOverrideIP = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.pendingGatewayOverrideIP = nil }
            Button("Block Gateway Anyway", role: .destructive) {
                if let ip = viewModel.pendingGatewayOverrideIP {
                    Task { await viewModel.confirmBlock(ip: ip) }
                }
                viewModel.pendingGatewayOverrideIP = nil
            }
        } message: {
            Text("\(viewModel.pendingGatewayOverrideIP ?? "This IP") appears to be your default gateway. Blocking it can disconnect this Mac from the network.")
        }
        .sheet(isPresented: $showingNmapWorkbench) {
            NmapCustomScanView(viewModel: nmapViewModel, targetIP: nmapTargetIP)
        }
        .sheet(isPresented: $showingIPSafetyReport) {
            IPSafetyReportView(ip: ipSafetyTargetIP, viewModel: ipSafetyViewModel)
        }
        .onChange(of: viewModel.selectedConnection?.remote?.address) { _, ip in
            if IPThroughputSettingsView.isEnabled {
                throughputViewModel.select(ip: ip)
            }
        }
    }

    private var rightInspector: some View {
        VStack(spacing: 0) {
            IPThroughputPanel(viewModel: throughputViewModel)
                .frame(maxHeight: 430)
            Divider()
            if let selected = viewModel.selectedConnection {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Block List Matches", systemImage: "exclamationmark.shield")
                        .font(.headline)
                    ReputationMatchesView(matches: reputationStore.matches(for: selected))
                }
                .padding(12)
                Divider()
            }
            BlockedIPsView(blockedIPs: viewModel.blockedIPs) { ip in
                Task { await viewModel.unblock(ip: ip) }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Label("Connections", systemImage: "network")
                .font(.headline)
            TextField("Search process, IP, port, protocol", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
            Picker("Interval", selection: $viewModel.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            Button {
                Task { await viewModel.refreshNow() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                Task { await viewModel.requestBlockSelectedConnection() }
            } label: {
                Label("Block Remote IP", systemImage: "hand.raised.fill")
            }
            .disabled(viewModel.selectedConnection?.remote?.address == nil)
            Spacer()
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Text("Last refreshed: \(viewModel.lastRefreshedAt.map(Self.timeFormatter.string(from:)) ?? "-")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
    }

    private var connectionTable: some View {
        Table(viewModel.filteredConnections, selection: $viewModel.selectedConnectionID) {
            TableColumn("Process") { connection in
                connectionCell(connection) {
                    Text(connection.processName)
                        .lineLimit(1)
                }
            }
            TableColumn("PID") { connection in
                connectionCell(connection) {
                    Text(connection.pid.map(String.init) ?? "-")
                        .monospacedDigit()
                }
            }
            TableColumn("Protocol") { connection in
                connectionCell(connection) {
                    Text(connection.protocolKind.rawValue)
                }
            }
            TableColumn("Direction") { connection in
                connectionCell(connection) {
                    Text(connection.direction.rawValue)
                }
            }
            TableColumn("Local") { connection in
                connectionCell(connection) {
                    endpointText(connection.local)
                }
            }
            TableColumn("Remote") { connection in
                connectionCell(connection) {
                    HStack(spacing: 6) {
                        if let remote = connection.remote {
                            endpointText(remote)
                        } else {
                            Text("-")
                        }
                        ReputationBadge(matches: reputationStore.matches(for: connection))
                    }
                }
            }
            TableColumn("State") { connection in
                connectionCell(connection) {
                    Text(connection.state.isEmpty ? "-" : connection.state)
                }
            }
            TableColumn("First Seen") { connection in
                connectionCell(connection) {
                    Text(Self.timeFormatter.string(from: connection.firstSeen))
                        .monospacedDigit()
                }
            }
            TableColumn("Last Seen") { connection in
                connectionCell(connection) {
                    Text(Self.timeFormatter.string(from: connection.lastSeen))
                        .monospacedDigit()
                }
            }
        }
        .transaction { $0.animation = nil }
    }

    private var polishedConnectionList: some View {
        ZStack {
            GradientBackground()
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(
                    "Live Connections",
                    subtitle: "\(viewModel.filteredConnections.count) active or recently observed connections",
                    systemImage: "network"
                )
                if viewModel.filteredConnections.isEmpty {
                    GlassPanel {
                        ContentUnavailableView(
                            "No live connections detected",
                            systemImage: "network.slash",
                            description: Text("Connections will appear here as network activity is observed.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.filteredConnections) { connection in
                                PrettyConnectionRow(
                                    processName: connection.processName,
                                    remoteIP: connection.remote?.address ?? "-",
                                    hostname: nil,
                                    countryRegion: nil,
                                    proto: connection.protocolKind.rawValue,
                                    port: connection.remote?.port ?? "-",
                                    direction: connection.direction.rawValue,
                                    status: prettyStatus(for: connection),
                                    trafficAmount: trafficText(for: connection),
                                    risk: riskLevel(for: connection),
                                    trafficHistory: trafficHistory(for: connection),
                                    selected: viewModel.selectedConnectionID == connection.id
                                ) {
                                    connectionContextMenu(for: connection)
                                }
                                .onTapGesture {
                                    viewModel.selectedConnectionID = connection.id
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(14)
        }
    }

    private func connectionCell<Content: View>(
        _ connection: NetworkConnection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu {
                connectionContextMenu(for: connection)
            }
    }

    @ViewBuilder
    private func connectionContextMenu(for connection: NetworkConnection) -> some View {
        if let remoteIP = connection.remote?.address, !remoteIP.isEmpty {
            Button {
                showThroughputGraph(target: remoteIP, pinned: false)
            } label: {
                Label("Show Throughput Graph", systemImage: "waveform.path.ecg")
            }
            Button {
                showThroughputGraph(target: remoteIP, pinned: true)
            } label: {
                Label("Pin Throughput Graph", systemImage: "pin")
            }
            Button {
                throughputViewModel.clear(ip: remoteIP)
            } label: {
                Label("Clear Throughput History", systemImage: "trash")
            }
            Button {
                throughputViewModel.exportCSV(ip: remoteIP)
            } label: {
                Label("Export Throughput CSV", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button {
                openIPSafetyReport(target: remoteIP, refresh: true)
            } label: {
                Label("Check IP Safety", systemImage: "shield.lefthalf.filled")
            }
            Button {
                openIPSafetyReport(target: remoteIP, refresh: false)
            } label: {
                Label("Open IP Safety Report", systemImage: "doc.text.magnifyingglass")
            }
            Button {
                if let report = ipSafetyViewModel.report, report.ip == remoteIP {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(IPSafetyViewModel.text(for: report), forType: .string)
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("No IP Safety summary is loaded for \(remoteIP). Choose Open IP Safety Report first.", forType: .string)
                }
            } label: {
                Label("Copy IP Safety Summary", systemImage: "doc.on.doc")
            }
            Divider()
            Button {
                runNmapPreset(.quick, target: remoteIP)
            } label: {
                Label("Quick Nmap Scan", systemImage: "bolt")
            }
            Button {
                runNmapPreset(.serviceVersion, target: remoteIP)
            } label: {
                Label("Service/Version Scan", systemImage: "list.bullet.rectangle")
            }
            Button {
                runNmapPreset(.osDetection, target: remoteIP)
            } label: {
                Label("OS Detection Scan", systemImage: "desktopcomputer")
            }
            Button {
                runNmapPreset(.aggressive, target: remoteIP)
            } label: {
                Label("Aggressive Scan", systemImage: "speedometer")
            }
            Button {
                openNmapWorkbench(target: remoteIP)
            } label: {
                Label("Custom Nmap...", systemImage: "slider.horizontal.3")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(remoteIP, forType: .string)
            } label: {
                Label("Copy IP Address", systemImage: "doc.on.doc")
            }
            Divider()
            if viewModel.blockedIPs.contains(remoteIP) {
                Button {
                    Task { await viewModel.unblock(ip: remoteIP) }
                } label: {
                    Label("Unblock \(remoteIP)", systemImage: "lock.open")
                }
            } else {
                Button {
                    Task { await viewModel.requestBlock(connection: connection) }
                } label: {
                    Label("Block \(remoteIP)", systemImage: "hand.raised.fill")
                }
            }
        } else {
            Button("No Remote IP") {}
                .disabled(true)
        }
    }

    private func runNmapPreset(_ preset: NmapPreset, target: String) {
        nmapTargetIP = target
        nmapViewModel.setWorkbenchTarget(target)
        showingNmapWorkbench = true
        nmapViewModel.runPreset(preset, target: target)
    }

    private func openNmapWorkbench(target: String) {
        nmapTargetIP = target
        nmapViewModel.setWorkbenchTarget(target)
        showingNmapWorkbench = true
    }

    private func openIPSafetyReport(target: String, refresh: Bool) {
        ipSafetyTargetIP = target
        showingIPSafetyReport = true
        ipSafetyViewModel.check(ip: target, refresh: refresh)
    }

    private func showThroughputGraph(target: String, pinned: Bool) {
        if pinned {
            throughputViewModel.pin(ip: target)
        } else {
            throughputViewModel.select(ip: target)
        }
        viewModel.selectedConnectionID = viewModel.connections.first { $0.remote?.address == target }?.id ?? viewModel.selectedConnectionID
    }

    private func endpointText(_ endpoint: NetworkEndpoint) -> some View {
        Text(endpoint.port.isEmpty ? endpoint.address : "\(endpoint.address):\(endpoint.port)")
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
    }

    private func prettyStatus(for connection: NetworkConnection) -> PrettyConnectionStatus {
        if let remoteIP = connection.remote?.address, viewModel.blockedIPs.contains(remoteIP) {
            return .blocked
        }
        let state = connection.state.uppercased()
        if state.contains("CLOSE") || state.contains("TIME_WAIT") { return .closing }
        if state.contains("LISTEN") || connection.direction == .listening { return .listening }
        if state.contains("ESTABLISHED") || connection.direction == .established { return .established }
        if state.isEmpty { return .unknown }
        return .unknown
    }

    private func riskLevel(for connection: NetworkConnection) -> ConnectionRiskLevel {
        if let remoteIP = connection.remote?.address, viewModel.blockedIPs.contains(remoteIP) {
            return .blocked
        }
        if !reputationStore.matches(for: connection).isEmpty {
            return .high
        }
        if connection.remote == nil { return .unknown }
        if connection.direction == .incoming { return .medium }
        return .low
    }

    private func trafficText(for connection: NetworkConnection) -> String {
        let inbound = connection.bytesInPerSecond ?? 0
        let outbound = connection.bytesOutPerSecond ?? 0
        let total = inbound + outbound
        if total > 0 {
            return ThroughputFormatter.string(bytesPerSecond: total, unit: .bytes)
        }
        let bytes = (connection.bytesIn ?? 0) + (connection.bytesOut ?? 0)
        return bytes == 0 ? "-" : ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func trafficHistory(for connection: NetworkConnection) -> [Double] {
        guard enableTrafficSparklines else { return [] }
        let total = (connection.bytesInPerSecond ?? 0) + (connection.bytesOutPerSecond ?? 0)
        guard total > 0 else { return [] }
        return [0, total * 0.35, total * 0.55, total * 0.40, total]
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

public struct BlockedIPsView: View {
    let blockedIPs: [String]
    let unblock: (String) -> Void

    public init(blockedIPs: [String], unblock: @escaping (String) -> Void) {
        self.blockedIPs = blockedIPs
        self.unblock = unblock
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Blocked IPs", systemImage: "shield")
                .font(.headline)
            if blockedIPs.isEmpty {
                Text("No PF blocks managed by this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(blockedIPs, id: \.self) { ip in
                    HStack {
                        Text(ip)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            unblock(ip)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Unblock \(ip)")
                    }
                }
            }
            Spacer()
            Text("PF anchor: \(FirewallBlockService.anchorName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}
