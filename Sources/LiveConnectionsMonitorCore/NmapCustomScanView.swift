import SwiftUI

public struct NmapCustomScanView: View {
    @ObservedObject var viewModel: NmapScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var favouriteName = ""

    public init(viewModel: NmapScanViewModel, targetIP: String) {
        self.viewModel = viewModel
        viewModel.setWorkbenchTarget(targetIP)
    }

    public var body: some View {
        NmapWorkbenchView(viewModel: viewModel, favouriteName: $favouriteName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
    }
}

public struct NmapWorkbenchView: View {
    @ObservedObject var viewModel: NmapScanViewModel
    @Binding var favouriteName: String

    public init(viewModel: NmapScanViewModel, favouriteName: Binding<String> = .constant("")) {
        self.viewModel = viewModel
        _favouriteName = favouriteName
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                presetSidebar
                    .frame(width: 230)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        targetAndOptions
                        commandPreview
                        runControls
                        if let comparison = viewModel.comparison {
                            comparisonView(comparison)
                        }
                        NmapResultsView(viewModel: viewModel)
                            .frame(minHeight: 560)
                    }
                    .padding(16)
                }
            }
            Divider()
            historyPanel
                .frame(height: 250)
        }
        .frame(minWidth: 1120, minHeight: 860)
    }

    private var presetSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nmap Workbench", systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            List(selection: $viewModel.selectedCategory) {
                ForEach(NmapPresetCategory.allCases) { category in
                    Text(category.rawValue)
                        .tag(category)
                }
            }

            if !viewModel.favourites.isEmpty {
                Text("Favourites")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                List(viewModel.favourites) { profile in
                    Button(profile.name) {
                        viewModel.applyFavourite(profile)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 140)
            }
        }
    }

    private var targetAndOptions: some View {
        GroupBox("Scan Builder") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("Target IP")
                    TextField("192.168.1.1", text: $viewModel.workbenchConfiguration.targetIP)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Preset")
                    Picker("Preset", selection: $viewModel.selectedWorkbenchPresetID) {
                        Text("Custom").tag(String?.none)
                        ForEach(viewModel.visiblePresets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                }
                GridRow {
                    Text("Ports")
                    Picker("Port mode", selection: $viewModel.workbenchConfiguration.portMode) {
                        ForEach(NmapPortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                if viewModel.workbenchConfiguration.portMode == .customPortList {
                    GridRow {
                        Text("Custom ports")
                        TextField("22,80,443,8000-9000", text: $viewModel.workbenchConfiguration.customPorts)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                GridRow {
                    Text("Timing")
                    Picker("Timing", selection: $viewModel.workbenchConfiguration.timing) {
                        ForEach(NmapTiming.allCases) { timing in
                            Text(timing.rawValue).tag(timing)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Divider().padding(.vertical, 6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 8) {
                Toggle("Ping scan", isOn: $viewModel.workbenchConfiguration.pingScan)
                Toggle("Service detection", isOn: $viewModel.workbenchConfiguration.serviceDetection)
                Toggle("OS detection", isOn: $viewModel.workbenchConfiguration.osDetection)
                Toggle("Default scripts", isOn: $viewModel.workbenchConfiguration.defaultScripts)
                Toggle("Traceroute", isOn: $viewModel.workbenchConfiguration.traceroute)
                Toggle("UDP scan", isOn: $viewModel.workbenchConfiguration.udpScan)
            }

            TextField("Extra arguments", text: $viewModel.workbenchConfiguration.extraArguments)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var commandPreview: some View {
        GroupBox("Live Command Preview") {
            Text(viewModel.workbenchCommandPreview)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var runControls: some View {
        HStack {
            ProgressView(value: viewModel.progressValue)
                .frame(width: 180)
            Text(viewModel.status.rawValue)
                .foregroundStyle(.secondary)
            Text("ETA: \(viewModel.estimatedCompletionText)")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("Favourite name", text: $favouriteName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            Button("Save Favourite") {
                viewModel.saveCurrentProfileAsFavourite(name: favouriteName)
                favouriteName = ""
            }
            Button("Run") {
                if let selectedID = viewModel.selectedWorkbenchPresetID,
                   let preset = viewModel.visiblePresets.first(where: { $0.id == selectedID }) {
                    viewModel.runWorkbenchPreset(preset, target: viewModel.workbenchConfiguration.targetIP)
                } else {
                    viewModel.runCustom(viewModel.workbenchConfiguration)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.status == .running)
            if viewModel.status == .running {
                Button("Cancel", role: .destructive) { viewModel.cancel() }
            }
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Nmap Scan History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                TextField("Search", text: $viewModel.historySearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                TextField("IP", text: $viewModel.historyIPFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Hostname", text: $viewModel.historyHostnameFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                TextField("Vendor", text: $viewModel.historyVendorFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                TextField("Scan type", text: $viewModel.historyScanTypeFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                Spacer()
                Button("Refresh") { Task { await viewModel.loadHistory() } }
                Button("Clear", role: .destructive) { viewModel.clearHistory() }
            }
            List(viewModel.filteredHistory) { item in
                HStack {
                    Text(item.targetIP).font(.system(.body, design: .monospaced)).frame(width: 120, alignment: .leading)
                    Text(item.parsedSummary?.hostname ?? "-").frame(width: 150, alignment: .leading)
                    Text(item.parsedSummary?.vendor ?? "-").frame(width: 150, alignment: .leading)
                    Text(item.presetName).frame(width: 180, alignment: .leading)
                    Text(item.startDate, style: .date)
                    Text(item.startDate, style: .time)
                    Spacer()
                    Text(item.exitCode.map(String.init) ?? "-").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    private func comparisonView(_ comparison: NmapScanComparison) -> some View {
        GroupBox("Changes Since Previous Scan") {
            VStack(alignment: .leading, spacing: 6) {
                if !comparison.newlyOpenedPorts.isEmpty {
                    Text("Newly opened: \(comparison.newlyOpenedPorts.map(\.id).joined(separator: ", "))").foregroundStyle(.green)
                }
                if !comparison.closedPorts.isEmpty {
                    Text("Closed: \(comparison.closedPorts.map(\.id).joined(separator: ", "))").foregroundStyle(.orange)
                }
                ForEach(comparison.serviceVersionChanges, id: \.self) { change in
                    Text(change)
                }
                if let hostnameChanged = comparison.hostnameChanged {
                    Text("Hostname: \(hostnameChanged)")
                }
                if let osFingerprintChanged = comparison.osFingerprintChanged {
                    Text("OS: \(osFingerprintChanged)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
