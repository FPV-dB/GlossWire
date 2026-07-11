import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct FirewallDashboardView: View {
    @ObservedObject private var viewModel: FirewallDashboardViewModel
    @ObservedObject private var reputationStore = ReputationBlockListStore.shared
    @EnvironmentObject private var applicationNetworkViewModel: ApplicationNetworkViewModel
    @EnvironmentObject private var throughputMonitor: NetworkThroughputMonitor
    @State private var showingImporter = false
    @State private var showingCountryImporter = false
    @State private var manualValue = ""
    @State private var allowValue = ""
    @State private var countryCode = ""
    @State private var countryName = ""
    @State private var countrySource = ""
    @State private var countryNotes = ""
    @State private var dontShowLookupWarningAgain = false
    @State private var dontShowTracerouteWarningAgain = false
    @AppStorage("visual.enableGradientBackground") private var enableGradientBackground = true
    @AppStorage("visual.enableGlassPanels") private var enableGlassPanels = true
    @AppStorage("visual.enableRowHoverGlow") private var enableRowHoverGlow = true
    @AppStorage("visual.enableTrafficSparklines") private var enableTrafficSparklines = true
    @AppStorage("visual.compactMode") private var compactMode = false
    @AppStorage("visual.reduceAnimations") private var reduceAnimations = false
    @AppStorage("visual.highContrastMode") private var highContrastMode = false

    public init(viewModel: FirewallDashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedSection) {
                ForEach(FirewallSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("Firewall")
        } detail: {
            Group {
                switch viewModel.selectedSection ?? .dashboard {
                case .dashboard:
                    dashboard
                case .liveConnections:
                    FirewallLiveConnectionsPage(viewModel: viewModel)
                case .applications:
                    ApplicationsNetworkView(viewModel: applicationNetworkViewModel)
                case .blockedIPs:
                    blockedIPs
                case .blocklists:
                    blocklists
                case .countryBlocking:
                    countryBlocking
                case .rules:
                    RulesPreviewView(rulePreview: viewModel.rulePreview) {
                        Task { await viewModel.applyRulesIfAllowed() }
                    }
                case .logs:
                    logs
                case .nmapWorkbench:
                    NmapWorkbenchView(viewModel: NmapScanViewModel())
                case .settings:
                    FirewallSettingsView(viewModel: viewModel)
                case .about:
                    ConnectionManagerAboutView()
                }
            }
            .navigationTitle(viewModel.selectedSection?.rawValue ?? "Dashboard")
            .toolbar {
                Button {
                    viewModel.reload()
                    Task { await viewModel.liveConnectionsViewModel.refreshNow() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            viewModel.liveConnectionsViewModel.start()
            viewModel.reload()
        }
        .onReceive(viewModel.liveConnectionsViewModel.$connections) { _ in
            viewModel.refreshRulePreview()
        }
        .onReceive(reputationStore.$rules) { _ in
            viewModel.refreshRulePreview()
        }
        .alert("Apply PF Rules?", isPresented: $viewModel.pendingApplyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply", role: .destructive) {
                Task { await viewModel.applyRules() }
            }
        } message: {
            Text("This writes and reloads only the app-managed PF anchor. Administrator permission will be requested.")
        }
        .sheet(isPresented: $viewModel.showLookupPrivacyWarning) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Third-party lookup", systemImage: "globe")
                    .font(.title3.weight(.semibold))
                Text("GeoIP/reputation lookup opens a third-party website and sends the selected IP address to that service. Only use this for IPs you intend to investigate.")
                Text("GeoIP results are approximate and can be wrong due to VPNs, CDNs, proxies, cloud hosting, and mobile networks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Don't show again", isOn: $dontShowLookupWarningAgain)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        dontShowLookupWarningAgain = false
                        viewModel.cancelPendingLookup()
                    }
                    Button("Open Lookup") {
                        viewModel.openPendingLookup(dontShowAgain: dontShowLookupWarningAgain)
                        dontShowLookupWarningAgain = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 460)
        }
        .sheet(isPresented: $viewModel.showTracerouteWarning) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Traceroute", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.title3.weight(.semibold))
                Text("Traceroute sends network probes toward the selected host. It may be logged by intermediate networks and may be blocked or misleading.")
                Toggle("Don't show again", isOn: $dontShowTracerouteWarningAgain)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        dontShowTracerouteWarningAgain = false
                        viewModel.showTracerouteWarning = false
                    }
                    Button("Run Traceroute") {
                        viewModel.confirmTraceroute(dontShowAgain: dontShowTracerouteWarningAgain)
                        dontShowTracerouteWarningAgain = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 460)
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

    private var dashboard: some View {
        ZStack {
            if enableGradientBackground {
                GradientBackground()
            } else {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardHero
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        MetricCard(title: "Active Connections", value: "\(viewModel.snapshot.activeConnections)", subtitle: "Observed now", systemImage: "network")
                        MetricCard(title: "Blocked", value: "\(viewModel.snapshot.blockedIPs)", subtitle: "PF managed IPs", systemImage: "shield.fill", accentGradient: VisualTheme(colorScheme: .dark).dangerGradient)
                        MetricCard(title: "Blocklists", value: "\(viewModel.snapshot.loadedBlocklists)", subtitle: "Loaded sources", systemImage: "list.bullet.rectangle")
                        MetricCard(title: "Suspicious", value: "\(viewModel.snapshot.blocksInLastHour)", subtitle: "Blocks last hour", systemImage: "exclamationmark.triangle.fill", accentGradient: VisualTheme(colorScheme: .dark).warningGradient)
                        MetricCard(title: "PF Status", value: viewModel.snapshot.pfStatus, subtitle: "Packet filter", systemImage: "switch.2")
                        MetricCard(title: "Total Traffic", value: viewModel.snapshot.lastRuleReload.map(Self.dateFormatter.string(from:)) ?? "-", subtitle: "Last reload", systemImage: "arrow.triangle.2.circlepath")
                    }
                    HStack(alignment: .top, spacing: 12) {
                        topList("Top remote IPs", rows: viewModel.snapshot.topRemoteIPs)
                        topList("Top processes", rows: viewModel.snapshot.topProcesses)
                    }
                }
                .padding(18)
            }
        }
    }

    private var dashboardHero: some View {
        GlassPanel(padding: 18, glow: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LIVE TRAFFIC")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(.cyan)
                        Text("Network radar")
                            .font(.largeTitle.weight(.semibold))
                        Text("Last 60 seconds of upload and download activity from the existing menu bar throughput monitor.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        StatusPill("Live", kind: .open)
                        Text("D \(ThroughputFormatter.string(bytesPerSecond: throughputMonitor.current.downloadBytesPerSecond, unit: throughputMonitor.rateUnit))")
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .monospacedDigit()
                        Text("U \(ThroughputFormatter.string(bytesPerSecond: throughputMonitor.current.uploadBytesPerSecond, unit: throughputMonitor.rateUnit))")
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                }
                TrafficSparkline(history: throughputMonitor.history)
                    .frame(height: 180)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 10) {
                            Label("Download", systemImage: "arrow.down")
                                .foregroundStyle(.cyan)
                            Label("Upload", systemImage: "arrow.up")
                                .foregroundStyle(.green)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(10)
                    }
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var blockedIPs: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("IP or CIDR", text: $manualValue)
                    .textFieldStyle(.roundedBorder)
                Button("Add Manual Block") {
                    viewModel.addManualBlock(manualValue)
                    manualValue = ""
                }
                .disabled(manualValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Table(viewModel.manualBlocks) {
                TableColumn("IP") { Text($0.address).font(.system(.body, design: .monospaced)) }
                TableColumn("Direction") { Text($0.direction.rawValue) }
                TableColumn("Source") { Text($0.source.rawValue) }
                TableColumn("Note") { Text($0.note) }
                TableColumn("Added") { Text(Self.dateFormatter.string(from: $0.dateAdded)) }
                TableColumn("Enabled") { block in
                    Toggle("", isOn: Binding(get: { block.isEnabled }, set: { viewModel.setManualBlockEnabled(id: block.id, enabled: $0) }))
                }
                TableColumn("Delete") { block in
                    Button("Unblock") { viewModel.deleteManualBlock(id: block.id) }
                }
            }
            Divider()
            HStack {
                TextField("Trusted allowlist IP/CIDR", text: $allowValue)
                    .textFieldStyle(.roundedBorder)
                Button("Add Allowlist") {
                    viewModel.addAllowlist(allowValue)
                    allowValue = ""
                }
            }
            Table(viewModel.allowlist) {
                TableColumn("Allowlisted") { Text($0.value).font(.system(.body, design: .monospaced)) }
                TableColumn("Note") { Text($0.note) }
                TableColumn("Delete") { entry in Button("Remove") { viewModel.deleteAllowlist(id: entry.id) } }
            }
            .frame(height: 150)
        }
        .padding(14)
    }

    private var blocklists: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Blocklist", systemImage: "square.and.arrow.down")
                }
                if !viewModel.importWarnings.isEmpty {
                    Text("\(viewModel.importWarnings.count) private/reserved warnings")
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
            Table(viewModel.blocklists) {
                TableColumn("Name") { Text($0.name) }
                TableColumn("File") { Text($0.sourceFilename) }
                TableColumn("Entries") { Text("\($0.entryCount)").monospacedDigit() }
                TableColumn("Imported") { Text(Self.dateFormatter.string(from: $0.importedAt)) }
                TableColumn("Enabled") { list in
                    Toggle("", isOn: Binding(get: { list.isEnabled }, set: { viewModel.setBlocklistEnabled(id: list.id, enabled: $0) }))
                }
                TableColumn("Last Applied") { Text($0.lastAppliedAt.map(Self.dateFormatter.string(from:)) ?? "-") }
            }
            if !viewModel.importWarnings.isEmpty {
                Text(viewModel.importWarnings.prefix(6).joined(separator: "\n"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.plainText, .commaSeparatedText, UTType(filenameExtension: "ip") ?? .plainText, UTType(filenameExtension: "list") ?? .plainText]) { result in
            if case let .success(url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                viewModel.importBlocklist(url: url)
            }
        }
    }

    private var countryBlocking: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Country-level blocking is opt-in", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Country-level blocking is broad and may block legitimate services, cloud platforms, CDNs, VPN endpoints, software updates, and ordinary users. Import only data you are licensed or allowed to use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Code, e.g. AU", text: $countryCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Country name", text: $countryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                TextField("Source", text: $countrySource)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes/reason", text: $countryNotes)
                    .textFieldStyle(.roundedBorder)
                Button("Import Country List") { showingCountryImporter = true }
                    .disabled(countryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let progress = viewModel.countryImportProgress {
                Text(progress).font(.caption).foregroundStyle(.secondary)
            }
            Table(viewModel.geoCountries) {
                TableColumn("Country") { Text($0.countryName) }
                TableColumn("Code") { Text($0.countryCode).font(.system(.body, design: .monospaced)) }
                TableColumn("IPv4") { Text("\($0.ipv4RangeCount)").monospacedDigit() }
                TableColumn("IPv6") { Text("\($0.ipv6RangeCount)").monospacedDigit() }
                TableColumn("Enabled") { country in
                    Toggle("", isOn: Binding(
                        get: { country.isEnabled },
                        set: { viewModel.setGeoCountryEnabled(code: country.countryCode, enabled: $0) }
                    ))
                }
                TableColumn("Direction") { country in
                    Picker("", selection: Binding(
                        get: { country.direction },
                        set: { viewModel.setGeoCountryDirection(code: country.countryCode, direction: $0) }
                    )) {
                        ForEach(FirewallDirection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                TableColumn("Last imported") { Text($0.lastImportedAt.map(Self.dateFormatter.string(from:)) ?? "-") }
                TableColumn("Source") { Text($0.sourceName) }
                TableColumn("Rule estimate") { Text("\($0.ruleCountEstimate)").monospacedDigit() }
                TableColumn("Notes") { country in
                    TextField("Notes", text: Binding(
                        get: { country.notes },
                        set: { viewModel.setGeoCountryNotes(code: country.countryCode, notes: $0) }
                    ))
                }
            }
            HStack {
                Button("Simulate Impact") { viewModel.simulateGeoImpact() }
                Button("Preview Rules") {
                    viewModel.simulateGeoImpact()
                    viewModel.selectedSection = .rules
                }
                Button("Apply Rules") {
                    viewModel.simulateGeoImpact()
                    Task { await viewModel.applyRulesIfAllowed() }
                }
                Spacer()
                Text("Estimated geo rules: \(viewModel.geoCountries.filter(\.isEnabled).reduce(0) { $0 + $1.ruleCountEstimate })")
                    .font(.caption)
                    .monospacedDigit()
            }
            geoSimulationSummary
        }
        .padding(14)
        .fileImporter(isPresented: $showingCountryImporter, allowedContentTypes: [.plainText, .commaSeparatedText, UTType(filenameExtension: "zone") ?? .plainText, UTType(filenameExtension: "cidr") ?? .plainText, UTType(filenameExtension: "list") ?? .plainText]) { result in
            if case let .success(url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                viewModel.importCountryList(
                    url: url,
                    countryCode: countryCode,
                    countryName: countryName.isEmpty ? countryCode.uppercased() : countryName,
                    sourceName: countrySource.isEmpty ? url.lastPathComponent : countrySource,
                    notes: countryNotes
                )
            }
        }
    }

    private var geoSimulationSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Simulation").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                summaryCard("Countries", "\(viewModel.geoSimulation.selectedCountries.count)", "globe")
                summaryCard("CIDR ranges", "\(viewModel.geoSimulation.cidrRangeCount)", "number")
                summaryCard("PF rules", "\(viewModel.geoSimulation.generatedRuleCount)", "curlybraces")
                summaryCard("Anchor size", "\(viewModel.geoSimulation.estimatedAnchorBytes) bytes", "doc")
                summaryCard("Affected connections", "\(viewModel.geoSimulation.affectedConnections.count)", "bolt.horizontal")
                summaryCard("Allowlist exemptions", "\(viewModel.geoSimulation.allowlistExemptions)", "checkmark.shield")
            }
            if !viewModel.geoSimulation.affectedProcesses.isEmpty {
                Text("Affected processes: \(viewModel.geoSimulation.affectedProcesses.map { "\($0.0) (\($0.1))" }.joined(separator: ", "))")
                    .font(.caption)
            }
            ForEach(viewModel.geoSimulation.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var logs: some View {
        ZStack {
            AppBackground()
            GlassCard(padding: 0) {
                Table(viewModel.events) {
                    TableColumn("Time") { Text(Self.dateFormatter.string(from: $0.date)).monospacedDigit() }
                    TableColumn("Event") { Text($0.eventType) }
                    TableColumn("Message") { Text($0.message) }
                    TableColumn("Detail") { Text($0.detail).font(.system(.body, design: .monospaced)) }
                    TableColumn("Result") { Text($0.succeeded ? "ok" : "failed").foregroundStyle($0.succeeded ? .green : .red) }
                }
            }
            .padding(14)
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ icon: String) -> some View {
        GlassMetricCard(title, value: value, systemImage: icon, accent: accent(for: title))
    }

    private func topList(_ title: String, rows: [(String, Int)]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0).font(.system(.body, design: .monospaced)).lineLimit(1)
                        Spacer()
                        Text("\(row.1)").monospacedDigit()
                    }
                }
                if rows.isEmpty {
                    Text("No data yet").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func accent(for title: String) -> Color {
        if title.localizedCaseInsensitiveContains("block") { return .red }
        if title.localizedCaseInsensitiveContains("allow") { return .green }
        if title.localizedCaseInsensitiveContains("PF") { return .orange }
        return .cyan
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

public struct FirewallLiveConnectionsPage: View {
    @ObservedObject var viewModel: FirewallDashboardViewModel
    @ObservedObject private var liveViewModel: LiveConnectionsViewModel
    @ObservedObject private var reputationStore = ReputationBlockListStore.shared
    @StateObject private var throughputViewModel: IPThroughputViewModel

    public init(viewModel: FirewallDashboardViewModel) {
        self.viewModel = viewModel
        self._liveViewModel = ObservedObject(wrappedValue: viewModel.liveConnectionsViewModel)
        self._throughputViewModel = StateObject(wrappedValue: IPThroughputViewModel(connectionsProvider: { viewModel.liveConnectionsViewModel.connections }))
    }

    public var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 12) {
                toolbar
                HSplitView {
                    GlassCard(padding: 0) {
                        connectionTable
                    }
                    detailsPanel
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
                }
            }
            .padding(14)
        }
        .onChange(of: liveViewModel.selectedConnection?.remote?.address) { _, ip in
            if IPThroughputSettingsView.isEnabled {
                throughputViewModel.select(ip: ip)
            }
        }
    }

    private var toolbar: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 10) {
                Label("Command Centre", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(.cyan)
            TextField("Search process, IP, port, protocol", text: Binding(
                get: { liveViewModel.searchText },
                set: { liveViewModel.searchText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            Picker("Interval", selection: Binding(
                get: { liveViewModel.refreshInterval },
                set: { liveViewModel.refreshInterval = $0 }
            )) {
                ForEach(RefreshInterval.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            Menu {
                ForEach(ConnectionSortField.allCases) { field in
                    Button {
                        liveViewModel.sortField = field
                    } label: {
                        HStack {
                            Text(field.rawValue)
                            if liveViewModel.sortField == field {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort: \(liveViewModel.sortField.rawValue)", systemImage: "arrow.up.arrow.down")
            }
            Button {
                liveViewModel.sortAscending.toggle()
            } label: {
                Label(liveViewModel.sortAscending ? "Ascending" : "Descending", systemImage: liveViewModel.sortAscending ? "arrow.up" : "arrow.down")
            }
            .help(liveViewModel.sortAscending ? "Ascending" : "Descending")
            Text("\(liveViewModel.sortField.rawValue) \(liveViewModel.sortAscending ? "Asc" : "Desc")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 92, alignment: .leading)
            Button("Geo Lookup") { viewModel.requestLookup() }
                .disabled(!canLookupSelected)
            Menu("Lookup With...") {
                providerButtons()
            }
            .disabled(!canLookupSelected)
            Button("Copy IP") { viewModel.copySelectedRemoteIP() }
                .disabled(liveViewModel.selectedConnection?.remote?.address == nil)
            Button("Block IP") { blockSelected() }
                .disabled(liveViewModel.selectedConnection?.remote?.address == nil)
            Button("Refresh") { Task { await liveViewModel.refreshNow() } }
            Text("Last refreshed: \(liveViewModel.lastRefreshedAt.map(Self.timeFormatter.string(from:)) ?? "-")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    private var connectionTable: some View {
        Table(liveViewModel.filteredConnections, selection: Binding(
            get: { liveViewModel.selectedConnectionID },
            set: { liveViewModel.selectedConnectionID = $0 }
        )) {
            TableColumn("Process") { connection in processCell(connection) }
            .width(150)
            TableColumn("Protocol") { connection in fixedCell(connection.protocolKind.rawValue, width: 72) }
                .width(72)
            TableColumn("Direction") { connection in directionCell(connection.direction, width: 95) }
                .width(95)
            TableColumn("Local") { connection in monoCell(endpoint(connection.local), width: 210) }
                .width(210)
            TableColumn("Remote") { connection in remoteEndpointCell(connection) }
                .width(230)
            TableColumn("Status") { connection in statusCell(connection, width: 110) }
                .width(110)
            TableColumn("Bytes In") { connection in numericCell(formatBytes(connection.bytesIn), width: 90) }
                .width(90)
            TableColumn("Bytes Out") { connection in numericCell(formatBytes(connection.bytesOut), width: 90) }
                .width(90)
            TableColumn("In/s") { connection in numericCell(formatRate(connection.bytesInPerSecond), width: 82) }
                .width(82)
            TableColumn("Out/s") { connection in numericCell(formatRate(connection.bytesOutPerSecond), width: 82) }
                .width(82)
        }
        .transaction { $0.animation = nil }
    }

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let connection = liveViewModel.selectedConnection {
                InspectorSection("Connection Details", systemImage: "info.circle") {
                    HStack {
                        ProcessIconLabel(connection.processName)
                        Spacer()
                        statusPill(for: connection)
                    }
                    detail("Remote IP", connection.remote?.address ?? "-")
                    detail("Remote port", connection.remote?.port ?? "-")
                    detail("Local", endpoint(connection.local))
                    detail("PID", connection.pid.map(String.init) ?? "-")
                    detail("Protocol", connection.protocolKind.rawValue)
                    detail("Direction", connection.direction.rawValue.capitalized)
                    detail("State", connection.state.isEmpty ? "-" : connection.state)
                }
                InspectorSection("Traffic", systemImage: "waveform.path.ecg") {
                    detail("Bytes in", formatBytes(connection.bytesIn))
                    detail("Bytes out", formatBytes(connection.bytesOut))
                    detail("Inbound rate", formatRate(connection.bytesInPerSecond))
                    detail("Outbound rate", formatRate(connection.bytesOutPerSecond))
                    detail("First seen", Self.dateTimeFormatter.string(from: connection.firstSeen))
                    detail("Last seen", Self.dateTimeFormatter.string(from: connection.lastSeen))
                }
                InspectorSection("Block List Matches", systemImage: "exclamationmark.shield") {
                    ReputationMatchesView(
                        matches: reputationStore.matches(for: connection),
                        blockingEnabled: viewModel.settings.blockReputationMatchedConnections
                    )
                }
                IPThroughputPanel(viewModel: throughputViewModel)
                InspectorSection("Actions", systemImage: "scope") {
                    HStack {
                        Button("Geo Lookup") { viewModel.requestLookup() }
                            .disabled(!canLookupSelected)
                        Button("Reputation") { viewModel.requestLookup(providerID: "talos") }
                            .disabled(!canLookupSelected)
                    }
                    HStack {
                        Button("Copy IP") { viewModel.copySelectedRemoteIP() }
                            .disabled(connection.remote?.address == nil)
                        Button("Block IP") { blockSelected() }
                            .disabled(connection.remote?.address == nil)
                    }
                    Text("GeoIP and reputation results are approximate and can be wrong due to VPNs, CDNs, proxies, cloud hosting, and mobile networks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Add note", text: $viewModel.selectedConnectionNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                advancedTools
            } else {
                GlassCard {
                    ContentUnavailableView("Select a connection", systemImage: "scope", description: Text("Inspect lookup, block, and traffic details for a live flow."))
                }
            }
            Spacer()
        }
    }

    private var advancedTools: some View {
        InspectorSection("Advanced Network Tools", systemImage: "wrench.and.screwdriver") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                Button("Web Geo Lookup") { viewModel.requestLookup() }
                    .disabled(!canLookupSelected)
                Button("Web Reputation Lookup") { viewModel.requestLookup(providerID: "talos") }
                    .disabled(!canLookupSelected)
                Button("Traceroute") { viewModel.requestTraceroute() }
                    .disabled(!canLookupSelected || viewModel.isNetworkToolRunning)
                Button("Ping") { viewModel.runNetworkTool(.ping) }
                    .disabled(!canLookupSelected || viewModel.isNetworkToolRunning)
                Button("Copy IP") { viewModel.copySelectedRemoteIP() }
                    .disabled(liveViewModel.selectedConnection?.remote?.address == nil)
            }
            if viewModel.isNetworkToolRunning {
                ProgressView()
                    .controlSize(.small)
            }
            TextEditor(text: Binding(
                get: { viewModel.networkToolOutput },
                set: { viewModel.networkToolOutput = $0 }
            ))
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 140)
            .border(.separator)
            HStack {
                Button("Stop") { viewModel.stopNetworkTool() }
                    .disabled(!viewModel.isNetworkToolRunning)
                Button("Copy Output") { viewModel.copyNetworkToolOutput() }
                    .disabled(viewModel.networkToolOutput.isEmpty)
                Button("Save Output") { viewModel.saveNetworkToolOutput() }
                    .disabled(viewModel.networkToolOutput.isEmpty)
            }
        }
    }

    private func status(for connection: NetworkConnection) -> String {
        guard let remote = connection.remote?.address else { return "-" }
        let manual = viewModel.manualBlocks.contains { $0.isEnabled && $0.address == remote }
        let imported = viewModel.blocklistEntries.contains { $0.isEnabled && $0.value == remote }
        let allowed = viewModel.allowlist.contains { $0.isEnabled && $0.value == remote }
        if allowed { return "allowlisted" }
        if manual || imported { return "blocked" }
        return "open"
    }

    private func statusKind(for connection: NetworkConnection) -> StatusPill.Kind {
        switch status(for: connection) {
        case "allowlisted": .allowlisted
        case "blocked": .blocked
        case "open": .open
        default: .neutral
        }
    }

    private func statusPill(for connection: NetworkConnection) -> StatusPill {
        StatusPill(status(for: connection), kind: statusKind(for: connection))
    }

    @ViewBuilder
    private func providerButtons() -> some View {
        ForEach(LookupProvider.presets) { provider in
            Button("\(provider.name) (\(provider.category.rawValue))") {
                viewModel.requestLookup(providerID: provider.id)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for connection: NetworkConnection) -> some View {
        Button("Geo Lookup") {
            liveViewModel.selectedConnectionID = connection.id
            viewModel.requestLookup()
        }
        Menu("Lookup with...") {
            ForEach(LookupProvider.presets) { provider in
                Button(provider.name) {
                    liveViewModel.selectedConnectionID = connection.id
                    viewModel.requestLookup(providerID: provider.id)
                }
            }
        }
        Button("Copy remote IP") {
            liveViewModel.selectedConnectionID = connection.id
            viewModel.copySelectedRemoteIP()
        }
        Button("Show Throughput Graph") {
            liveViewModel.selectedConnectionID = connection.id
            if let ip = connection.remote?.address { throughputViewModel.select(ip: ip) }
        }
        Button("Pin Throughput Graph") {
            liveViewModel.selectedConnectionID = connection.id
            if let ip = connection.remote?.address { throughputViewModel.pin(ip: ip) }
        }
        Button("Clear Throughput History") {
            if let ip = connection.remote?.address { throughputViewModel.clear(ip: ip) }
        }
        Button("Export Throughput CSV") {
            if let ip = connection.remote?.address { throughputViewModel.exportCSV(ip: ip) }
        }
        Button("Block remote IP") {
            liveViewModel.selectedConnectionID = connection.id
            blockSelected()
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
        }
    }

    private func processCell(_ connection: NetworkConnection) -> some View {
        ProcessIconLabel(connection.processName)
            .frame(width: 150, alignment: .leading)
            .contextMenu { contextMenu(for: connection) }
    }

    private func remoteCell(_ connection: NetworkConnection) -> some View {
        Text(connection.remote?.address ?? "-")
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .frame(width: 170, alignment: .leading)
            .contextMenu { contextMenu(for: connection) }
    }

    private func remoteEndpointCell(_ connection: NetworkConnection) -> some View {
        HStack(spacing: 6) {
            Text(connection.remote.map(endpoint) ?? "-")
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            ReputationBadge(matches: reputationStore.matches(for: connection))
        }
        .frame(width: 230, alignment: .leading)
        .contextMenu { contextMenu(for: connection) }
    }

    private func fixedCell(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }

    private func statusCell(_ connection: NetworkConnection, width: CGFloat) -> some View {
        statusPill(for: connection)
            .frame(width: width, alignment: .leading)
            .contextMenu { contextMenu(for: connection) }
    }

    private func directionCell(_ direction: ConnectionDirection, width: CGFloat) -> some View {
        let symbol: String = switch direction {
        case .incoming: "arrow.down.left"
        case .outgoing: "arrow.up.right"
        case .listening: "dot.radiowaves.left.and.right"
        case .established: "arrow.left.arrow.right"
        case .unknown: "questionmark"
        }
        return Label(direction.rawValue.capitalized, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func monoCell(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }

    private func numericCell(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .monospacedDigit()
            .frame(width: width, alignment: .trailing)
    }

    private func endpoint(_ endpoint: NetworkEndpoint) -> String {
        endpoint.port.isEmpty ? endpoint.address : "\(endpoint.address):\(endpoint.port)"
    }

    private func formatBytes(_ value: UInt64?) -> String {
        guard let value else { return "-" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }

    private func formatRate(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(value.rounded()), countStyle: .binary))/s"
    }

    private func blockSelected() {
        if let ip = liveViewModel.selectedConnection?.remote?.address {
            viewModel.addManualBlock(ip, note: viewModel.selectedConnectionNote.isEmpty ? "Blocked from live connection" : viewModel.selectedConnectionNote)
        }
    }

    private var canLookupSelected: Bool {
        guard let ip = liveViewModel.selectedConnection?.remote?.address else { return false }
        if case .success = LookupService().canLookup(ip: ip) {
            return true
        }
        return false
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

public struct ConnectionManagerAboutView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 42))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection Manager")
                            .font(.largeTitle.weight(.semibold))
                        Text("Native macOS firewall dashboard and live connection monitor.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                aboutCard("What It Does") {
                    Text("Connection Manager helps inspect live network activity, review process connections, manage app-owned PF firewall rules, import blocklists, and monitor throughput from the menu bar.")
                }

                aboutCard("Credits") {
                    Text("Created by FPV-dB.")
                        .font(.headline)
                    Text("Thank you for using, testing, and improving the app.")
                        .foregroundStyle(.secondary)
                }

                aboutCard("Source And Use Terms") {
                    Text("This project is open-source/source-available for personal and non-commercial use.")
                    Text("You are free to copy, study, and modify it as you please, as long as you credit FPV-dB.")
                    Text("You agree not to sell the app, sell modified versions, sell bundled copies, or use any part of this project in a product or service offered for sale.")
                        .foregroundStyle(.orange)
                }

                aboutCard("Safety Model") {
                    Text("The app is built for defensive visibility and user-confirmed firewall changes. It uses dedicated PF anchors, avoids global PF flushes, and does not perform packet capture, credential capture, traffic interception, or stealth behavior.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func aboutCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}

public struct RulesPreviewView: View {
    let rulePreview: String
    let apply: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Generated PF Rules", systemImage: "curlybraces.square")
                    .font(.headline)
                Spacer()
                Button("Apply Anchor") { apply() }
            }
            TextEditor(text: .constant(rulePreview))
                .font(.system(.body, design: .monospaced))
                .border(.separator)
        }
        .padding(14)
    }
}

public struct FirewallSettingsView: View {
    @ObservedObject var viewModel: FirewallDashboardViewModel
    @EnvironmentObject private var throughputMonitor: NetworkThroughputMonitor
    @State private var acknowledgedStartupRisk = false
    @State private var acknowledgedStrictRisk = false
    @AppStorage("visual.enableGradientBackground") private var enableGradientBackground = true
    @AppStorage("visual.enableGlassPanels") private var enableGlassPanels = true
    @AppStorage("visual.enableRowHoverGlow") private var enableRowHoverGlow = true
    @AppStorage("visual.enableTrafficSparklines") private var enableTrafficSparklines = true
    @AppStorage("visual.compactMode") private var compactMode = false
    @AppStorage("visual.reduceAnimations") private var reduceAnimations = false
    @AppStorage("visual.highContrastMode") private var highContrastMode = false

    public var body: some View {
        ScrollView {
            Form {
                Section("Startup") {
                    Toggle("Launch Connection Manager on boot", isOn: Binding(
                        get: { viewModel.settings.launchAtLogin },
                        set: { viewModel.setLaunchAtLogin($0) }
                    ))
                    LabeledContent("Status", value: viewModel.loginItemStatus)
                    LabeledContent("Last startup", value: viewModel.settings.lastStartupAt.map(Self.dateFormatter.string(from:)) ?? "-")
                }

                Section("Startup Protection") {
                    Text("This feature can affect network connectivity during startup. Incorrect firewall rules may temporarily prevent internet access until corrected.")
                        .foregroundStyle(.orange)
                    Picker("Startup Mode", selection: $viewModel.settings.startupMode) {
                        ForEach(StartupProtectionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    ForEach(StartupProtectionMode.allCases) { mode in
                        Text("\(mode.rawValue): \(mode.detail)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("PF Enabled", value: viewModel.startupStatus.pfEnabled)
                    LabeledContent("Startup Anchor Installed", value: viewModel.startupStatus.startupAnchorInstalled ? "Yes" : "No")
                    LabeledContent("Rules Loaded", value: viewModel.startupStatus.rulesLoaded ? "Yes" : "No")
                    LabeledContent("Last Synchronization", value: viewModel.startupStatus.lastSynchronization.map(Self.dateFormatter.string(from:)) ?? "-")
                    HStack {
                        Button("Apply Startup Protection") {
                            viewModel.requestStartupProtectionApply()
                        }
                        Button("Rollback Startup Protection") {
                            Task { await viewModel.rollbackStartupProtection() }
                        }
                        Button("Refresh Status") {
                            Task { await viewModel.refreshStartupStatus() }
                        }
                    }
                }

                Section("Firewall") {
                    Toggle("Auto-apply imported blocklists", isOn: $viewModel.settings.autoApplyImportedBlocklists)
                    Toggle("Block live connections that match enabled Block Lists", isOn: Binding(
                        get: { viewModel.settings.blockReputationMatchedConnections },
                        set: { viewModel.setReputationBlockingEnabled($0) }
                    ))
                    Text("When enabled, matching live connections are added to the app-managed PF rules by remote IP. Review the Generated PF Rules screen and apply the anchor to activate changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Confirm before applying firewall changes", isOn: $viewModel.settings.confirmBeforeApplying)
                    Toggle("Backup previous app anchor file before rewriting", isOn: $viewModel.settings.backupAnchorBeforeRewrite)
                    TextField("PF anchor path", text: $viewModel.settings.anchorPath)
                    TextField("App anchor name", text: $viewModel.settings.anchorName)
                }

                Section("Known Provider Blocking") {
                    Toggle("Block all published Google and Google Cloud IP ranges", isOn: Binding(
                        get: { viewModel.settings.blockKnownGoogleConnections },
                        set: { viewModel.requestGoogleBlocking($0) }
                    ))
                    Text("Uses Google's official goog.json and cloud.json feeds. This is IP-range blocking, not hostname filtering, and includes customer-hosted Google Cloud services.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("Managed ranges", value: viewModel.googleRangeCount.formatted())
                    LabeledContent("Last refreshed", value: viewModel.settings.googleRangesLastUpdatedAt.map(Self.dateFormatter.string(from:)) ?? "Never")
                    if let progress = viewModel.googleBlockingProgress {
                        ProgressView(progress)
                    }
                    Button("Refresh Google Ranges") {
                        Task { await viewModel.refreshGoogleRanges() }
                    }
                    .disabled(!viewModel.settings.blockKnownGoogleConnections || viewModel.googleBlockingProgress != nil)
                }

                Section("Live Connections") {
                    Picker("Refresh interval", selection: $viewModel.settings.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Menu Bar Throughput") {
                    Toggle("Show live throughput in the menu bar", isOn: $throughputMonitor.displayEnabled)
                    Picker("Rate unit", selection: $throughputMonitor.rateUnit) {
                        ForEach(ThroughputRateUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Picker("Update interval", selection: $throughputMonitor.updateInterval) {
                        ForEach(ThroughputUpdateInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    Picker("Display mode", selection: $throughputMonitor.displayMode) {
                        ForEach(ThroughputDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Text("Measures byte-counter deltas across active non-loopback interfaces. Choose auto-scaling or a fixed KB/MB/GB/Kb/Mb/Gb display unit for the menu bar and popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DataMilestoneSoundsSettingsView(manager: throughputMonitor.dataMilestoneSoundManager)

                BlockListsSettingsView()

                Section("Lookups") {
                    Picker("Default lookup provider", selection: $viewModel.settings.defaultLookupProviderID) {
                        ForEach(LookupProvider.presets) { provider in
                            Text("\(provider.name) - \(provider.category.rawValue)").tag(provider.id)
                        }
                    }
                    Toggle("Do not show GeoIP/reputation lookup privacy warning again", isOn: $viewModel.settings.suppressLookupPrivacyWarning)
                    Toggle("Do not show traceroute warning again", isOn: $viewModel.settings.suppressTracerouteWarning)
                }

                Section("Nmap") {
                    TextField("Custom nmap path", text: $viewModel.settings.nmapPath)
                        .font(.system(.body, design: .monospaced))
                    Text("Leave blank to auto-detect /opt/homebrew/bin/nmap, /usr/local/bin/nmap, or /usr/bin/nmap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                IPSafetySettingsView()

                IPThroughputSettingsView()

                Section("Visual Appearance") {
                    Toggle("Enable gradient background", isOn: $enableGradientBackground)
                    Toggle("Enable glass panels", isOn: $enableGlassPanels)
                    Toggle("Enable row hover glow", isOn: $enableRowHoverGlow)
                    Toggle("Enable traffic sparklines", isOn: $enableTrafficSparklines)
                    Toggle("Compact mode", isOn: $compactMode)
                    Toggle("Reduce animations", isOn: $reduceAnimations)
                    Toggle("High contrast mode", isOn: $highContrastMode)
                    Text("These settings are visual only and do not change firewall, logging, menu bar, or Nmap behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Save Settings") {
                    viewModel.saveSettings()
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(18)
        }
        .alert("Enable Protection at Boot?", isPresented: $viewModel.showStartupProtectionConfirmation) {
            Toggle("I understand this may affect network connectivity during startup.", isOn: $acknowledgedStartupRisk)
            Button("Cancel", role: .cancel) { acknowledgedStartupRisk = false }
            Button("Install Startup Anchor", role: .destructive) {
                viewModel.confirmStartupProtection(acknowledged: acknowledgedStartupRisk)
                acknowledgedStartupRisk = false
            }
        } message: {
            Text("Connection Manager will install and load the dedicated startup PF anchor \(StartupProtectionService.startupAnchor). Incorrect firewall rules may temporarily prevent internet access until corrected.")
        }
        .alert("Strict Startup Lock", isPresented: $viewModel.showStrictStartupConfirmation) {
            Toggle("I have read the recovery warning and accept the risk.", isOn: $acknowledgedStrictRisk)
            Button("Cancel", role: .cancel) { acknowledgedStrictRisk = false }
            Button("Enable Strict Startup Lock", role: .destructive) {
                viewModel.confirmStartupProtection(acknowledged: acknowledgedStrictRisk)
                acknowledgedStrictRisk = false
            }
        } message: {
            Text("Strict Startup Lock can block most network traffic until Connection Manager starts. Recovery: reopen Settings and use Rollback Startup Protection, or remove /etc/pf.anchors/com.connectionmanager.startup with administrator privileges and reload that anchor.")
        }
        .alert("Block Known Google Connections?", isPresented: $viewModel.showGoogleBlockingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Download Ranges and Continue", role: .destructive) {
                Task { await viewModel.enableGoogleBlocking() }
            }
        } message: {
            Text("This broad block includes Google Search, Gmail, YouTube, Android services, Chrome synchronization, reCAPTCHA, Firebase, Google APIs, and customer-hosted Google Cloud services. Many unrelated websites and apps may stop working. The official range feeds will be downloaded, previewed in the app-managed PF anchor, and applied through the normal administrator-confirmation flow.")
        }
        .alert("Disable Google Blocking?", isPresented: $viewModel.showGoogleDisableConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disable and Update Rules") {
                Task { await viewModel.disableGoogleBlocking() }
            }
        } message: {
            Text("The managed Google blocklist will remain stored for audit history but will be disabled and removed from generated PF rules.")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

private struct DataMilestoneSoundsSettingsView: View {
    @ObservedObject var manager: DataMilestoneSoundManager

    var body: some View {
        Section("Data Milestone Sounds") {
            Toggle("Enable milestone sounds", isOn: $manager.enabled)

            Picker("Traffic direction", selection: $manager.direction) {
                ForEach(DataMilestoneDirection.allCases) { direction in
                    Text(direction.label).tag(direction)
                }
            }

            HStack {
                TextField("Threshold", value: $manager.thresholdValue, format: .number.precision(.fractionLength(0...2)))
                    .frame(maxWidth: 120)
                Picker("Unit", selection: $manager.thresholdUnit) {
                    ForEach(DataMilestoneUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .labelsHidden()
                Text("Current threshold: \(DataMilestoneSoundManager.formatBytes(manager.thresholdBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Sound", selection: $manager.selectedSound) {
                ForEach(DataMilestoneSoundSelection.allCases) { sound in
                    Text(sound.label).tag(sound)
                }
            }

            if manager.selectedSound == .systemSound {
                Picker("System sound", selection: $manager.systemSoundName) {
                    ForEach(DataMilestoneSoundManager.systemSoundNames, id: \.self) { soundName in
                        Text(soundName).tag(soundName)
                    }
                }
            }

            if manager.selectedSound == .customFile {
                HStack {
                    Button("Choose Audio File") {
                        manager.chooseCustomSound()
                    }
                    Text(manager.customSoundURL?.lastPathComponent ?? "No custom sound selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Volume")
                    Slider(value: $manager.volume, in: 0...1)
                    Text("\(Int((manager.volume * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                HStack {
                    TextField("Cooldown", value: $manager.cooldownSeconds, format: .number.precision(.fractionLength(0...1)))
                        .frame(maxWidth: 120)
                    Text("seconds between sounds")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progressFraction)
                Text(manager.progressDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Test Sound") {
                    manager.testSound()
                }
                Button("Reset Counter") {
                    manager.resetCounter()
                }
            }

            if let warningMessage = manager.warningMessage {
                Text(warningMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Uses the existing menu-bar byte counters. Milestone progress persists across restarts, and audio playback is rate-limited so a large traffic jump only plays one sound.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var progressFraction: Double {
        guard manager.thresholdBytes > 0 else { return 0 }
        return min(1, max(0, Double(manager.currentIntervalBytes) / Double(manager.thresholdBytes)))
    }
}
