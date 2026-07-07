import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public final class NmapScanViewModel: ObservableObject {
    @Published public private(set) var status: NmapScanStatus = .ready
    @Published public private(set) var targetIP = ""
    @Published public private(set) var presetName = ""
    @Published public private(set) var commandArguments: [String] = []
    @Published public private(set) var commandPreview = ""
    @Published public private(set) var output = ""
    @Published public private(set) var startTime: Date?
    @Published public private(set) var endTime: Date?
    @Published public private(set) var exitCode: Int32?
    @Published public private(set) var parsedSummary: NmapParsedSummary?
    @Published public private(set) var comparison: NmapScanComparison?
    @Published public private(set) var history: [NmapScanHistoryItem] = []
    @Published public private(set) var favourites: [NmapFavouriteProfile] = []
    @Published public var workbenchConfiguration = NmapCustomScanConfiguration(targetIP: "")
    @Published public var selectedCategory: NmapPresetCategory = .portDiscovery
    @Published public var selectedWorkbenchPresetID: String?
    @Published public var historySearchText = ""
    @Published public var historyIPFilter = ""
    @Published public var historyHostnameFilter = ""
    @Published public var historyVendorFilter = ""
    @Published public var historyScanTypeFilter = ""
    @Published public var historyStartDate: Date?
    @Published public var historyEndDate: Date?
    @Published public var errorMessage: String?

    private let service: NmapScanService
    private let historyStore: NmapHistoryStore
    private var scanTask: Task<Void, Never>?
    private var nmapPathProvider: @MainActor () -> String

    public init(
        service: NmapScanService = NmapScanService(),
        historyStore: NmapHistoryStore = NmapHistoryStore(),
        nmapPathProvider: @escaping @MainActor () -> String = { UserDefaults.standard.string(forKey: "nmap.customPath") ?? "" }
    ) {
        self.service = service
        self.historyStore = historyStore
        self.nmapPathProvider = nmapPathProvider
        Task { await loadHistory() }
    }

    public var visiblePresets: [NmapWorkbenchPreset] {
        NmapWorkbenchPreset.builtIns.filter { $0.category == selectedCategory }
    }

    public var progressValue: Double? {
        status == .running ? nil : (status == .ready ? 0 : 1)
    }

    public var estimatedCompletionText: String {
        guard status == .running, let startTime else { return "-" }
        let elapsed = Date().timeIntervalSince(startTime)
        if commandArguments.contains("-A") || commandArguments.contains("-O") || commandArguments.contains("-sU") {
            return elapsed < 45 ? "About 1-3 minutes" : "Still running"
        }
        return elapsed < 15 ? "Under 1 minute" : "Still running"
    }

    public var workbenchCommandPreview: String {
        do {
            return try service.commandPreview(arguments: try workbenchConfiguration.arguments(), customPath: nmapPathProvider())
        } catch {
            return error.localizedDescription
        }
    }

    public var filteredHistory: [NmapScanHistoryItem] {
        let search = historySearchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ip = historyIPFilter.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hostname = historyHostnameFilter.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let vendor = historyVendorFilter.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let scanType = historyScanTypeFilter.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return history.filter { item in
            if !ip.isEmpty, !item.targetIP.lowercased().contains(ip) { return false }
            if !hostname.isEmpty, !(item.parsedSummary?.hostname ?? "").lowercased().contains(hostname) { return false }
            if !vendor.isEmpty, !(item.parsedSummary?.vendor ?? "").lowercased().contains(vendor) { return false }
            if !scanType.isEmpty, !item.presetName.lowercased().contains(scanType) { return false }
            if let historyStartDate, item.startDate < historyStartDate { return false }
            if let historyEndDate, item.startDate > historyEndDate { return false }
            if !search.isEmpty {
                let haystack = [
                    item.targetIP,
                    item.presetName,
                    item.parsedSummary?.hostname ?? "",
                    item.parsedSummary?.vendor ?? "",
                    item.parsedSummary?.osFingerprint ?? "",
                    item.rawOutput
                ].joined(separator: " ").lowercased()
                if !haystack.contains(search) { return false }
            }
            return true
        }
    }

    public var durationText: String {
        guard let startTime else { return "-" }
        let end = endTime ?? Date()
        return String(format: "%.1fs", end.timeIntervalSince(startTime))
    }

    public func runPreset(_ preset: NmapPreset, target: String) {
        run(presetName: preset.rawValue, target: target, arguments: preset.arguments(target: target))
    }

    public func runWorkbenchPreset(_ preset: NmapWorkbenchPreset, target: String) {
        let cleanTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        run(presetName: preset.name, target: cleanTarget, arguments: preset.arguments + [cleanTarget])
    }

    public func runCustom(_ configuration: NmapCustomScanConfiguration) {
        do {
            run(presetName: NmapPreset.custom.rawValue, target: configuration.targetIP, arguments: try configuration.arguments())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setWorkbenchTarget(_ target: String) {
        workbenchConfiguration.targetIP = target
    }

    public func cancel() {
        status = .cancelled
        scanTask?.cancel()
        service.cancel()
        endTime = Date()
    }

    public func copyResults() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    public func saveResults() {
        exportResults(format: .txt)
    }

    public func exportResults(format: NmapExportFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "nmap-\(targetIP)-results.\(format.fileExtension)"
        panel.allowedContentTypes = contentTypes(for: format)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            switch format {
            case .txt:
                try output.write(to: url, atomically: true, encoding: .utf8)
            case .json:
                let item = currentHistoryItem()
                let data = try JSONEncoder().encode(item)
                try data.write(to: url, options: .atomic)
            case .xml:
                try xmlExport().write(to: url, atomically: true, encoding: .utf8)
            case .html:
                try htmlExport().write(to: url, atomically: true, encoding: .utf8)
            case .pdf:
                try pdfData().write(to: url, options: .atomic)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadHistory() async {
        do {
            history = try await historyStore.load()
            favourites = try await historyStore.loadFavourites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearHistory() {
        Task {
            do {
                try await historyStore.clear()
                await loadHistory()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func saveCurrentProfileAsFavourite(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var next = favourites
        next.insert(NmapFavouriteProfile(id: UUID(), name: cleanName, configuration: workbenchConfiguration), at: 0)
        Task {
            do {
                try await historyStore.saveFavourites(next)
                await loadHistory()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func applyFavourite(_ profile: NmapFavouriteProfile) {
        workbenchConfiguration = profile.configuration
    }

    private func run(presetName: String, target: String, arguments: [String]) {
        guard status != .running else { return }
        guard NmapScanService.isAllowedTarget(target) else {
            errorMessage = NmapScanError.publicTarget.localizedDescription
            return
        }

        do {
            commandPreview = try service.commandPreview(arguments: arguments, customPath: nmapPathProvider())
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        self.targetIP = target
        self.presetName = presetName
        commandArguments = arguments
        output = ""
        parsedSummary = nil
        comparison = nil
        exitCode = nil
        errorMessage = nil
        startTime = Date()
        endTime = nil
        status = .running

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let code = try await service.run(arguments: arguments, customPath: nmapPathProvider()) { text in
                    Task { @MainActor in
                        self.output += text
                    }
                }
                guard !Task.isCancelled else { return }
                exitCode = code
                endTime = Date()
                parsedSummary = NmapOutputParser.parse(output)
                comparison = comparisonForCurrentResult()
                status = code == 0 ? .completed : .failed
                await persistCurrentResult()
            } catch {
                guard !Task.isCancelled else { return }
                endTime = Date()
                errorMessage = error.localizedDescription
                output += "\n\(error.localizedDescription)\n"
                parsedSummary = NmapOutputParser.parse(output)
                comparison = comparisonForCurrentResult()
                status = .failed
                await persistCurrentResult()
            }
        }
    }

    private func currentHistoryItem() -> NmapScanHistoryItem {
        NmapScanHistoryItem(
            id: UUID(),
            targetIP: targetIP,
            presetName: presetName,
            commandArguments: commandArguments,
            rawOutput: output,
            parsedSummary: parsedSummary,
            startDate: startTime ?? Date(),
            endDate: endTime,
            exitCode: exitCode
        )
    }

    private func persistCurrentResult() async {
        guard let startTime else { return }
        let item = NmapScanHistoryItem(
            id: UUID(),
            targetIP: targetIP,
            presetName: presetName,
            commandArguments: commandArguments,
            rawOutput: output,
            parsedSummary: parsedSummary,
            startDate: startTime,
            endDate: endTime,
            exitCode: exitCode
        )
        do {
            try await historyStore.append(item)
            await loadHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func comparisonForCurrentResult() -> NmapScanComparison? {
        let previous = history.first { $0.targetIP == targetIP && $0.parsedSummary != nil }?.parsedSummary
        return NmapOutputParser.compare(current: parsedSummary, previous: previous)
    }

    private func contentTypes(for format: NmapExportFormat) -> [UTType] {
        switch format {
        case .txt: [.plainText]
        case .json: [.json]
        case .xml: [.xml]
        case .html: [.html]
        case .pdf: [.pdf]
        }
    }

    private func xmlExport() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <nmapScan>
          <target>\(escapeXML(targetIP))</target>
          <preset>\(escapeXML(presetName))</preset>
          <command>\(escapeXML(commandPreview))</command>
          <output>\(escapeXML(output))</output>
        </nmapScan>
        """
    }

    private func htmlExport() -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Nmap \(targetIP)</title>
        <style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:24px}pre{font-family:Menlo,monospace;white-space:pre-wrap;background:#111;color:#eee;padding:16px;border-radius:8px}</style></head>
        <body><h1>Nmap Scan: \(escapeHTML(targetIP))</h1><p><strong>Command:</strong> \(escapeHTML(commandPreview))</p><pre>\(escapeHTML(output))</pre></body></html>
        """
    }

    private func pdfData() throws -> Data {
        let text = "Nmap Scan: \(targetIP)\nCommand: \(commandPreview)\n\n\(output)"
        let attr = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.textColor
        ])
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw NmapScanError.launchFailed("Unable to create PDF export.")
        }
        var y: CGFloat = 36
        context.beginPDFPage([kCGPDFContextMediaBox as String: page] as CFDictionary)
        let lines = attr.string.components(separatedBy: .newlines)
        for line in lines {
            if y > page.height - 36 {
                context.endPDFPage()
                context.beginPDFPage([kCGPDFContextMediaBox as String: page] as CFDictionary)
                y = 36
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            (line as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)])
            NSGraphicsContext.restoreGraphicsState()
            y += 13
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func escapeXML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeHTML(_ value: String) -> String {
        escapeXML(value)
    }
}
