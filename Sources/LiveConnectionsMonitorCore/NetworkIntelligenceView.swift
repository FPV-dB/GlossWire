import AppKit
import Charts
import SwiftUI

public struct NetworkIntelligenceView: View {
    @ObservedObject private var viewModel: ApplicationNetworkViewModel
    @State private var section = IntelligenceSection.journal
    @State private var searchText = ""
    @State private var quietMode = false
    @StateObject private var timeCapsule = NetworkTimeCapsuleViewModel()

    public init(viewModel: ApplicationNetworkViewModel) { self.viewModel = viewModel }

    public var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Network Intelligence").font(.title2.weight(.semibold))
                        Text("Context accumulated from retained endpoint metadata.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Privacy Mode", isOn: $viewModel.privacyModeEnabled).toggleStyle(.switch)
                    Toggle("Quiet Mode", isOn: $quietMode).toggleStyle(.switch)
                    Button { exportInvestigationPackage() } label: { Label("Export Package", systemImage: "archivebox") }
                    TextField("Search", text: $searchText).textFieldStyle(.roundedBorder).frame(width: 240)
                }
                Picker("Section", selection: $section) {
                    ForEach(IntelligenceSection.allCases) { item in Text(item.rawValue).tag(item) }
                }.pickerStyle(.segmented)
                content
            }.padding(16)
        }
        .onAppear { viewModel.start(); Task { await viewModel.reloadTimeline() } }
    }

    @ViewBuilder private var content: some View {
        let analyzer = NetworkIntelligenceAnalyzer()
        switch section {
        case .overview: overview(analyzer)
        case .journal: journal(analyzer)
        case .passports: passports(analyzer)
        case .memory: memory(analyzer)
        case .ports: ports(analyzer)
        case .domains: domains(analyzer)
        case .calendar: calendar(analyzer)
        case .signals: signals(analyzer)
        case .timeCapsule: timeCapsuleView
        }
    }

    private func overview(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let ratings = analyzer.internetRatings(records: viewModel.timelineHistory).filter { matches($0.id) }
        let fingerprint = analyzer.fingerprint(records: viewModel.timelineHistory)
        let signals = analyzer.behaviourSignals(records: viewModel.timelineHistory)
        return ScrollView {
            VStack(spacing: 12) {
                if !quietMode || !signals.isEmpty {
                    GlassCard { VStack(alignment: .leading, spacing: 8) { Label("Explain My Computer", systemImage: "text.bubble").font(.headline); Text(analyzer.explainMyComputer(records: viewModel.timelineHistory)).textSelection(.enabled); Text("Generated locally without an AI or cloud service.").font(.caption).foregroundStyle(.secondary) } }
                    GlassCard { HStack { VStack(alignment: .leading) { Text("Internet Fingerprint").font(.headline); Text(fingerprint.currentSignature).font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); Text(fingerprint.similarityPercent.map { "\($0)% like yesterday" } ?? "Needs two days").font(.title3.monospacedDigit()) } }
                }
                if quietMode && signals.isEmpty { ContentUnavailableView("Quiet", systemImage: "moon.zzz", description: Text("No supported changes or behavioural signals are currently visible.")) }
                if !quietMode {
                    ForEach(ratings) { rating in
                        GlassCard { VStack(alignment: .leading, spacing: 6) { HStack { Text(maskProcess(rating.id)).font(.headline); Spacer(); Text("\(rating.score)/100 · \(rating.label)").font(.headline.monospacedDigit()) }; ProgressView(value: Double(rating.score), total: 100).tint(rating.score >= 70 ? .green : .orange); Text("Encrypted-service observations \(rating.encryptedPercent)% · Entropy \(rating.destinationEntropy.formatted(.number.precision(.fractionLength(2)))) · Noise \(rating.observationsPerHour.formatted(.number.precision(.fractionLength(1))))/hour").font(.caption); Text(rating.explanation).font(.caption2).foregroundStyle(.secondary) } }
                    }
                }
            }
        }
    }

    private func journal(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Network Journal", systemImage: "book.pages").font(.title3.weight(.semibold))
                    Text(analyzer.journal(records: viewModel.timelineHistory)).font(.body).textSelection(.enabled)
                    Text("Generated locally. No telemetry is sent to an AI service.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func passports(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let rows = analyzer.passports(records: viewModel.timelineHistory).filter { matches($0.id) }
        return List(rows) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(maskProcess(item.id)).font(.headline); Spacer(); Text("Confidence \(item.confidence)%").font(.caption.monospacedDigit()) }
                Text("First online \(item.firstOnline.formatted(date: .abbreviated, time: .shortened)) · Last \(item.lastOnline.formatted(date: .abbreviated, time: .shortened)) · \(item.daysSeen) days seen")
                Text("\(item.observations.formatted()) observations · \(item.uniqueDestinations) destinations · Typical/day \(item.typicalConnectionsPerDay.lowerBound)–\(item.typicalConnectionsPerDay.upperBound)")
                Text("Ports: \(item.typicalPorts.joined(separator: ", "))  Countries: \(item.typicalCountries.isEmpty ? "Unresolved" : item.typicalCountries.joined(separator: ", "))")
            }.font(.caption).padding(.vertical, 5)
        }
    }

    private func memory(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let rows = analyzer.networkMemory(records: viewModel.timelineHistory).filter { matches($0.id) || $0.processes.contains(where: matches) }
        return List(rows) { item in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PrivacyRedactor.address(item.id, enabled: viewModel.privacyModeEnabled)).font(.headline.monospaced())
                    Text("First contacted \(item.firstSeen.formatted(date: .abbreviated, time: .shortened)) · Last \(item.lastSeen.formatted(date: .abbreviated, time: .shortened))")
                    Text("Seen on \(item.daysSeen) days · \(item.observations) observations · Apps: \(item.processes.map(maskProcess).joined(separator: ", "))")
                    Text("Ports: \(item.ports.joined(separator: ", "))")
                }.font(.caption)
                Spacer()
                Text(item.totalBytes.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .binary) } ?? "Bytes unavailable").font(.caption.monospacedDigit())
            }.padding(.vertical, 5)
        }
    }

    private func ports(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let rows = analyzer.ports(records: viewModel.timelineHistory).filter { matches($0.id) || matches($0.service) }
        return Chart(rows.prefix(20)) { item in
            BarMark(x: .value("Observations", item.count), y: .value("Port", "\(item.id) · \(item.service)"))
                .foregroundStyle(.cyan.gradient)
                .annotation(position: .trailing) { Text(item.count.formatted()).font(.caption2) }
        }.padding(12)
    }

    private func domains(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let rows = analyzer.domainFamilies(records: viewModel.timelineHistory).filter { matches($0.id) }
        return List(rows) { item in
            HStack { Text(viewModel.privacyModeEnabled ? "hidden.example" : item.id).font(.headline.monospaced()); Spacer(); Text("\(item.count) observations · \(item.hosts) hosts").font(.caption.monospacedDigit()) }
        }
    }

    private func calendar(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let rows = analyzer.calendarActivity(records: viewModel.timelineHistory)
        return Chart(rows) { item in
            RectangleMark(x: .value("Day", item.day, unit: .day), y: .value("Week", Calendar.current.component(.weekOfYear, from: item.day)))
                .foregroundStyle(by: .value("Activity", item.observations))
        }.chartForegroundStyleScale(range: Gradient(colors: [.gray.opacity(0.2), .green])).padding(12)
    }

    private func signals(_ analyzer: NetworkIntelligenceAnalyzer) -> some View {
        let signals = analyzer.behaviourSignals(records: viewModel.timelineHistory).filter { matches($0.process) || matches($0.detail) }
        let capabilities = analyzer.detectionCapabilities(provider: .processCounters)
        return ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Behaviour Signals", systemImage: "waveform.path.ecg").font(.headline)
                        if signals.isEmpty { Text("No supported behavioural signals were found in retained history.").foregroundStyle(.secondary) }
                        ForEach(signals) { signal in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { Text(signal.kind.rawValue).font(.subheadline.weight(.semibold)); Spacer(); Text("\(signal.confidence)% pattern confidence").font(.caption.monospacedDigit()) }
                                Text(maskProcess(signal.process)).font(.caption.monospaced())
                                Text(signal.detail).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Detection Coverage").font(.headline)
                        ForEach(capabilities) { item in
                            HStack(alignment: .top) {
                                Image(systemName: item.available ? "checkmark.circle.fill" : "lock.circle").foregroundStyle(item.available ? .green : .secondary)
                                VStack(alignment: .leading) { Text(item.id).font(.subheadline.weight(.medium)); Text(item.detail).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var timeCapsuleView: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) {
            HStack { VStack(alignment: .leading) { Text("Network Time Capsule").font(.title3.weight(.semibold)); Text("One durable system-and-network context snapshot per day while GlossWire runs.").foregroundStyle(.secondary) }; Spacer(); Button { Task { await timeCapsule.capture(records: viewModel.timelineHistory) } } label: { Label("Capture Now", systemImage: "camera.metering.center.weighted") }.disabled(timeCapsule.capturing) }
            if let error = timeCapsule.error { Text(error).foregroundStyle(.orange).font(.caption) }
            if timeCapsule.snapshots.isEmpty { ContentUnavailableView("No snapshots", systemImage: "archivebox", description: Text("Capture a snapshot or leave GlossWire running for its first daily capture.")) }
            ForEach(timeCapsule.snapshots) { item in GlassCard { VStack(alignment: .leading, spacing: 5) { HStack { Text(item.timestamp.formatted(date: .long, time: .shortened)).font(.headline); Spacer(); Text("\(item.observedProcesses.count) processes · \(item.activeDestinations.count) destinations").font(.caption.monospacedDigit()) }; Text("Wi-Fi: \(item.wifiNetwork ?? "Unavailable") · Gateway: \(item.gateway ?? "Unavailable") · IPv4 \(item.ipv4Available ? "yes" : "no") · IPv6 \(item.ipv6Available ? "yes" : "no")").font(.caption); Text("Installed apps \(item.installedApplications.count) · Observed LAN devices \(item.observedLANDevices.count)").font(.caption); DisclosureGroup("Snapshot details") { Text("Apps: \(item.installedApplications.joined(separator: ", "))\n\nLAN: \(item.observedLANDevices.joined(separator: ", "))\n\nUnavailable: \(item.unavailableEvidence.joined(separator: "; "))\n\nRouting table:\n\(item.routingTable)").font(.caption.monospaced()).textSelection(.enabled) } } } }
        }.padding(4) }.task { await timeCapsule.captureDailyIfNeeded(records: viewModel.timelineHistory) }
    }

    private func matches(_ value: String) -> Bool { searchText.isEmpty || value.localizedCaseInsensitiveContains(searchText) }
    private func maskProcess(_ value: String) -> String { PrivacyRedactor.process(value, enabled: viewModel.privacyModeEnabled) }
    private func exportInvestigationPackage() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.zip]; panel.nameFieldStringValue = "GlossWire-investigation-\(Date().formatted(.iso8601.year().month().day())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let records = viewModel.timelineHistory, privacy = viewModel.privacyModeEnabled
        Task {
            let weather = await InternetWeatherStore().load()
            let bookmarks = TimelineBookmarkStore().bookmarks
            let snapshots = await NetworkTimeCapsuleStore().load()
            do { try await InvestigationPackageExporter().export(to: url, records: records, weather: weather, bookmarks: bookmarks, snapshots: snapshots, privacyMode: privacy) }
            catch { viewModel.errorMessage = "Could not export investigation package: \(error.localizedDescription)" }
        }
    }
}

private enum IntelligenceSection: String, CaseIterable, Identifiable { case overview = "Overview", journal = "Journal", passports = "Passports", memory = "Network Memory", ports = "Ports", domains = "Domains", calendar = "Calendar", signals = "Signals", timeCapsule = "Time Capsule"; var id: String { rawValue } }
