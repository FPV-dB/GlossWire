import AppKit
import Foundation

@MainActor
public final class FirewallDashboardViewModel: ObservableObject {
    @Published public var selectedSection: FirewallSection? = .dashboard
    @Published public private(set) var snapshot = FirewallDashboardSnapshot()
    @Published public private(set) var blocklists: [Blocklist] = []
    @Published public private(set) var blocklistEntries: [BlocklistEntry] = []
    @Published public private(set) var manualBlocks: [ManualBlockedIP] = []
    @Published public private(set) var allowlist: [AllowlistEntry] = []
    @Published public private(set) var geoCountries: [GeoBlockCountry] = []
    @Published public private(set) var geoRanges: [GeoBlockRange] = []
    @Published public var geoSimulation = GeoBlockSimulation()
    @Published public var countryImportProgress: String?
    @Published public private(set) var events: [FirewallEventLog] = []
    @Published public var settings = FirewallSettings()
    @Published public var rulePreview = ""
    @Published public var errorMessage: String?
    @Published public var importWarnings: [String] = []
    @Published public var pendingApplyConfirmation = false
    @Published public var pendingLookupProviderID: String?
    @Published public var pendingLookupIP: String?
    @Published public var showLookupPrivacyWarning = false
    @Published public var showTracerouteWarning = false
    @Published public var selectedConnectionNote = ""
    @Published public var networkToolOutput = ""
    @Published public var isNetworkToolRunning = false
    @Published public var startupStatus = StartupProtectionStatus()
    @Published public var loginItemStatus = "Unknown"
    @Published public var showStartupProtectionConfirmation = false
    @Published public var showStrictStartupConfirmation = false
    @Published public var showGoogleBlockingConfirmation = false
    @Published public var showGoogleDisableConfirmation = false
    @Published public var googleBlockingProgress: String?
    @Published public var showMicrosoftBlockingConfirmation = false
    @Published public var showMicrosoftDisableConfirmation = false
    @Published public var microsoftBlockingProgress: String?
    @Published public var showTorBlockingConfirmation = false
    @Published public var showTorDisableConfirmation = false
    @Published public var torBlockingProgress: String?
    @Published public var showStopAllBlockingConfirmation = false
    @Published public var isChangingEmergencyBlockingState = false
    @Published public var showInternetKillSwitchConfirmation = false

    public let liveConnectionsViewModel: LiveConnectionsViewModel
    private let database: FirewallDatabase
    private let importer = BlocklistImportService()
    private let generator = FirewallRuleGenerator()
    private let firewallService: FirewallBlockService
    private let lookupService = LookupService()
    private let networkToolRunner = NetworkToolRunner()
    private let loginItemService = LoginItemService()
    private let startupProtectionService = StartupProtectionService()
    private let googleIPRangeService = GoogleIPRangeService()
    private let microsoftIPRangeService = MicrosoftIPRangeService()
    private let torRelayRangeService = TorRelayRangeService()
    private let reputationStore = ReputationBlockListStore.shared
    private var didSynchronizeStrictStartupLockAfterLaunch = false

    public init(database: FirewallDatabase, liveConnectionsViewModel: LiveConnectionsViewModel, firewallService: FirewallBlockService) {
        self.database = database
        self.liveConnectionsViewModel = liveConnectionsViewModel
        self.firewallService = firewallService
        reload()
    }

    public func reload() {
        do {
            settings = try database.settings()
            blocklists = try database.blocklists()
            blocklistEntries = try database.entries()
            manualBlocks = try database.manualBlocks()
            allowlist = try database.allowlist()
            geoCountries = try database.geoCountries()
            geoRanges = try database.geoRanges()
            events = try database.events()
            liveConnectionsViewModel.refreshInterval = settings.refreshInterval
            loginItemStatus = loginItemService.status()
            rebuildPreview()
            rebuildSnapshot()
            Task {
                await refreshStartupStatus()
                await synchronizeStrictStartupLockAfterLaunchIfNeeded()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func importBlocklist(url: URL) {
        do {
            let result = try importer.importFile(url: url, database: database)
            importWarnings = result.warnings
            try database.insertEvent(type: "Blocklist imported", message: url.lastPathComponent, detail: "\(result.importedEntries) imported, \(result.skippedEntries) skipped", succeeded: true)
            reload()
            if settings.autoApplyImportedBlocklists {
                Task { await applyRulesIfAllowed() }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addManualBlock(_ value: String, note: String = "Manual block", direction: FirewallDirection = .both) {
        do {
            try database.insertManualBlock(address: value, direction: direction, note: note)
            try database.insertEvent(type: "Connection blocked manually", message: value, detail: note, succeeded: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteManualBlock(id: Int64) {
        do {
            try database.deleteManualBlock(id: id)
            try database.insertEvent(type: "Rule removed", message: "Manual block removed", detail: "id \(id)", succeeded: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setManualBlockEnabled(id: Int64, enabled: Bool) {
        do {
            try database.setManualBlockEnabled(id: id, enabled: enabled)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setBlocklistEnabled(id: Int64, enabled: Bool) {
        do {
            try database.setBlocklistEnabled(id: id, enabled: enabled)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addAllowlist(_ value: String, note: String = "Trusted") {
        do {
            try database.insertAllowlist(value: value, note: note)
            try database.insertEvent(type: "Allowlist updated", message: value, detail: note, succeeded: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteAllowlist(id: Int64) {
        do {
            try database.deleteAllowlist(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSettings() {
        do {
            try database.save(settings: settings)
            UserDefaults.standard.set(settings.nmapPath, forKey: "nmap.customPath")
            liveConnectionsViewModel.refreshInterval = settings.refreshInterval
            try loginItemService.setEnabled(settings.launchAtLogin)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setReputationBlockingEnabled(_ enabled: Bool) {
        settings.blockReputationMatchedConnections = enabled
        saveSettings()
    }

    public func setServiceBlocked(_ service: NetworkServiceBlockPreset, enabled: Bool) {
        if enabled {
            settings.blockedServiceIDs.insert(service.id)
        } else {
            settings.blockedServiceIDs.remove(service.id)
        }
        do {
            try database.save(settings: settings)
            try database.insertEvent(
                type: enabled ? "Network service blocked" : "Network service unblocked",
                message: service.name,
                detail: service.detail,
                succeeded: true
            )
            reload()
            Task { await applyRulesIfAllowed() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stopAllBlocking() async {
        showStopAllBlockingConfirmation = false
        isChangingEmergencyBlockingState = true
        settings.isBlockingPaused = true
        do {
            try database.save(settings: settings)
            rebuildPreview()
            try await firewallService.apply(anchorText: rulePreview, settings: settings)
            try await startupProtectionService.rollback()
            settings.startupAnchorInstalled = false
            settings.startupRulesLoaded = false
            settings.lastStartupSynchronizationAt = Date()
            try database.save(settings: settings)
            try database.insertEvent(type: "Emergency blocking pause", message: "All GlossWire blocking stopped", detail: "App and startup anchors cleared; configuration preserved", succeeded: true)
            reload()
        } catch {
            try? database.insertEvent(type: "Emergency blocking pause failed", message: "Could not clear every GlossWire anchor", detail: error.localizedDescription, succeeded: false)
            errorMessage = "Emergency stop may be incomplete: \(error.localizedDescription)"
            reload()
        }
        isChangingEmergencyBlockingState = false
    }

    public func resumeAllBlocking() async {
        isChangingEmergencyBlockingState = true
        settings.isBlockingPaused = false
        do {
            try database.save(settings: settings)
            rebuildPreview()
            try await firewallService.apply(anchorText: rulePreview, settings: settings)
            if settings.startupMode != .monitorOnly {
                try await startupProtectionService.install(mode: settings.startupMode, rulePreview: rulePreview, backup: settings.backupAnchorBeforeRewrite)
                settings.startupAnchorInstalled = true
                settings.startupRulesLoaded = true
                settings.lastStartupSynchronizationAt = Date()
                try database.save(settings: settings)
            }
            try database.insertEvent(type: "Emergency blocking resumed", message: "GlossWire blocking restored", detail: "Saved app and startup rules reapplied", succeeded: true)
            reload()
        } catch {
            settings.isBlockingPaused = true
            try? database.save(settings: settings)
            try? database.insertEvent(type: "Emergency blocking resume failed", message: "Saved rules were not fully restored", detail: error.localizedDescription, succeeded: false)
            errorMessage = "Blocking remains paused: \(error.localizedDescription)"
            reload()
        }
        isChangingEmergencyBlockingState = false
    }

    public func setInternetKillSwitch(_ enabled: Bool) async {
        showInternetKillSwitchConfirmation = false
        isChangingEmergencyBlockingState = true
        let previous = settings.internetKillSwitchEnabled
        settings.internetKillSwitchEnabled = enabled
        do {
            try database.save(settings: settings)
            rebuildPreview()
            try await firewallService.apply(anchorText: rulePreview, settings: settings)
            try database.insertEvent(type: enabled ? "Internet kill switch enabled" : "Internet kill switch disabled", message: enabled ? "Public-network traffic isolated" : "Normal routing restored", detail: "Loopback and LAN policy preserved", succeeded: true)
            reload()
        } catch {
            settings.internetKillSwitchEnabled = previous
            try? database.save(settings: settings)
            rebuildPreview()
            errorMessage = "Internet kill switch change failed: \(error.localizedDescription)"
        }
        isChangingEmergencyBlockingState = false
    }

    public func refreshRulePreview() {
        rebuildPreview()
        rebuildSnapshot()
    }

    public var googleRangeCount: Int {
        guard let blocklist = blocklists.first(where: { $0.name == GoogleIPRangeService.managedBlocklistName }) else { return 0 }
        return blocklist.entryCount
    }

    public var microsoftRangeCount: Int {
        guard let blocklist = blocklists.first(where: { $0.name == MicrosoftIPRangeService.managedBlocklistName }) else { return 0 }
        return blocklist.entryCount
    }

    public var torRelayRangeCount: Int {
        blocklists.first(where: { $0.name == TorRelayRangeService.managedBlocklistName })?.entryCount ?? 0
    }

    public var connectionsFirstSeenInLastMinute: Int {
        let cutoff = Date().addingTimeInterval(-60)
        return liveConnectionsViewModel.connections.filter { $0.firstSeen >= cutoff }.count
    }

    public var recentSecurityEventCount: Int {
        let cutoff = Date().addingTimeInterval(-3600)
        return events.filter { event in
            event.date >= cutoff && (event.eventType.localizedCaseInsensitiveContains("block") || !event.succeeded)
        }.count
    }

    public func requestTorBlocking(_ enabled: Bool) {
        if enabled { showTorBlockingConfirmation = true } else { showTorDisableConfirmation = true }
    }

    public func enableTorBlocking() async {
        showTorBlockingConfirmation = false
        torBlockingProgress = "Downloading the Tor Project's current public relay catalogue..."
        do {
            let result = try await torRelayRangeService.fetchRunningRelayRanges()
            try database.replaceManagedBlocklist(
                name: TorRelayRangeService.managedBlocklistName,
                sourceFilename: "Tor Project Onionoo summary",
                notes: "Known running public Tor relay addresses. Bridges and other proxies may bypass this list.",
                entries: result.ranges,
                enabled: true
            )
            settings.blockKnownTorRelays = true
            settings.torRangesLastUpdatedAt = result.publishedAt ?? result.fetchedAt
            try database.save(settings: settings)
            try database.insertEvent(type: "Tor blocking enabled", message: "Known public Tor relays", detail: "\(result.ranges.count) relay addresses prepared", succeeded: true)
            torBlockingProgress = nil
            reload()
            await applyRulesIfAllowed()
        } catch {
            torBlockingProgress = nil
            try? database.insertEvent(type: "Tor range refresh failed", message: "Known public Tor relays", detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
        }
    }

    public func refreshTorRanges() async {
        guard settings.blockKnownTorRelays else { return }
        await enableTorBlocking()
    }

    public func disableTorBlocking() async {
        showTorDisableConfirmation = false
        do {
            try database.setManagedBlocklistEnabled(name: TorRelayRangeService.managedBlocklistName, enabled: false)
            settings.blockKnownTorRelays = false
            try database.save(settings: settings)
            try database.insertEvent(type: "Tor blocking disabled", message: "Known public Tor relays", detail: "Managed ranges removed from generated rules", succeeded: true)
            reload()
            await applyRulesIfAllowed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func requestGoogleBlocking(_ enabled: Bool) {
        if enabled {
            showGoogleBlockingConfirmation = true
        } else {
            showGoogleDisableConfirmation = true
        }
    }

    public func enableGoogleBlocking() async {
        showGoogleBlockingConfirmation = false
        googleBlockingProgress = "Downloading Google's official IP range feeds..."
        do {
            let result = try await googleIPRangeService.fetchAllKnownRanges()
            try database.replaceManagedBlocklist(
                name: GoogleIPRangeService.managedBlocklistName,
                sourceFilename: "goog.json + cloud.json",
                notes: "Official Google service and Google Cloud customer ranges. Broad blocking preset.",
                entries: result.ranges,
                enabled: true
            )
            settings.blockKnownGoogleConnections = true
            settings.googleRangesLastUpdatedAt = result.fetchedAt
            try database.save(settings: settings)
            try database.insertEvent(type: "Google blocking enabled", message: "Known Google ranges", detail: "\(result.ranges.count) ranges prepared", succeeded: true)
            googleBlockingProgress = nil
            reload()
            await applyRulesIfAllowed()
        } catch {
            googleBlockingProgress = nil
            try? database.insertEvent(type: "Google range refresh failed", message: "Known Google ranges", detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
        }
    }

    public func refreshGoogleRanges() async {
        guard settings.blockKnownGoogleConnections else { return }
        await enableGoogleBlocking()
    }

    public func disableGoogleBlocking() async {
        showGoogleDisableConfirmation = false
        do {
            try database.setManagedBlocklistEnabled(name: GoogleIPRangeService.managedBlocklistName, enabled: false)
            settings.blockKnownGoogleConnections = false
            try database.save(settings: settings)
            try database.insertEvent(type: "Google blocking disabled", message: "Known Google ranges", detail: "Managed ranges removed from generated rules", succeeded: true)
            reload()
            await applyRulesIfAllowed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func requestMicrosoftBlocking(_ enabled: Bool) {
        if enabled {
            showMicrosoftBlockingConfirmation = true
        } else {
            showMicrosoftDisableConfirmation = true
        }
    }

    public func enableMicrosoftBlocking() async {
        showMicrosoftBlockingConfirmation = false
        microsoftBlockingProgress = "Downloading Microsoft's public Azure service tag ranges..."
        do {
            let result = try await microsoftIPRangeService.fetchAllKnownRanges()
            try database.replaceManagedBlocklist(
                name: MicrosoftIPRangeService.managedBlocklistName,
                sourceFilename: "ServiceTags_Public.json",
                notes: "Microsoft public Azure service tag ranges. Broad blocking preset.",
                entries: result.ranges,
                enabled: true
            )
            settings.blockKnownMicrosoftConnections = true
            settings.microsoftRangesLastUpdatedAt = result.fetchedAt
            try database.save(settings: settings)
            try database.insertEvent(type: "Microsoft blocking enabled", message: "Known Microsoft ranges", detail: "\(result.ranges.count) ranges prepared", succeeded: true)
            microsoftBlockingProgress = nil
            reload()
            await applyRulesIfAllowed()
        } catch {
            microsoftBlockingProgress = nil
            try? database.insertEvent(type: "Microsoft range refresh failed", message: "Known Microsoft ranges", detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
        }
    }

    public func refreshMicrosoftRanges() async {
        guard settings.blockKnownMicrosoftConnections else { return }
        await enableMicrosoftBlocking()
    }

    public func disableMicrosoftBlocking() async {
        showMicrosoftDisableConfirmation = false
        do {
            try database.setManagedBlocklistEnabled(name: MicrosoftIPRangeService.managedBlocklistName, enabled: false)
            settings.blockKnownMicrosoftConnections = false
            try database.save(settings: settings)
            try database.insertEvent(type: "Microsoft blocking disabled", message: "Known Microsoft ranges", detail: "Managed ranges removed from generated rules", succeeded: true)
            reload()
            await applyRulesIfAllowed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            settings.launchAtLogin = enabled
            if enabled && settings.startupMode == .monitorOnly {
                settings.startupMode = .strictStartupLock
                showStrictStartupConfirmation = true
            }
            try database.save(settings: settings)
            loginItemStatus = loginItemService.status()
        } catch {
            settings.launchAtLogin = false
            errorMessage = error.localizedDescription
            loginItemStatus = loginItemService.status()
        }
    }

    public func setStartupMode(_ mode: StartupProtectionMode) {
        guard settings.startupMode != mode else { return }
        settings.startupMode = mode
        settings.startupAcknowledged = false
        settings.startupAnchorInstalled = false
        settings.startupRulesLoaded = false
        settings.lastStartupSynchronizationAt = nil
        do {
            try database.save(settings: settings)
            Task { await refreshStartupStatus() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func requestStartupProtectionApply() {
        if settings.startupMode == .monitorOnly {
            Task { await rollbackStartupProtection() }
        } else if settings.startupMode == .strictStartupLock {
            showStrictStartupConfirmation = true
        } else {
            showStartupProtectionConfirmation = true
        }
    }

    public func confirmStartupProtection(acknowledged: Bool) {
        guard acknowledged else {
            errorMessage = "Acknowledge the startup protection warning before applying."
            return
        }
        showStartupProtectionConfirmation = false
        showStrictStartupConfirmation = false
        Task { await installStartupProtection() }
    }

    public func refreshStartupStatus() async {
        startupStatus = await startupProtectionService.status(settings: settings)
        rebuildSnapshot()
    }

    public func checkPFStatusWithAdministratorPrivileges() async {
        do {
            startupStatus.pfEnabled = try await startupProtectionService.privilegedPFStatus()
            rebuildSnapshot()
        } catch {
            errorMessage = "Unable to check PF status: \(error.localizedDescription)"
        }
    }

    public func enablePF() async {
        do {
            startupStatus.pfEnabled = try await startupProtectionService.enablePF()
            try database.insertEvent(type: "PF enabled", message: "Enabled from GlossWire", detail: "Administrator-approved pfctl -e", succeeded: true)
            rebuildSnapshot()
        } catch {
            try? database.insertEvent(type: "PF enable failed", message: "Could not enable PF", detail: error.localizedDescription, succeeded: false)
            errorMessage = "Unable to enable PF: \(error.localizedDescription)"
        }
    }

    public func installStartupProtection() async {
        do {
            try await startupProtectionService.install(mode: settings.startupMode, rulePreview: rulePreview, backup: settings.backupAnchorBeforeRewrite)
            settings.startupAcknowledged = true
            settings.startupAnchorInstalled = settings.startupMode != .monitorOnly
            settings.startupRulesLoaded = settings.startupMode != .monitorOnly
            settings.lastStartupSynchronizationAt = Date()
            try database.save(settings: settings)
            try database.insertEvent(type: "Startup protection synchronized", message: settings.startupMode.rawValue, detail: StartupProtectionService.startupAnchor, succeeded: true)
            reload()
        } catch {
            try? database.insertEvent(type: "Startup protection failed", message: settings.startupMode.rawValue, detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
            reload()
        }
    }

    public func synchronizeStrictStartupLockAfterLaunchIfNeeded() async {
        guard !didSynchronizeStrictStartupLockAfterLaunch else { return }
        guard settings.launchAtLogin, settings.startupMode == .strictStartupLock, settings.startupRulesLoaded else { return }
        didSynchronizeStrictStartupLockAfterLaunch = true
        do {
            try await startupProtectionService.synchronizeRuntimeAfterLaunch(rulePreview: rulePreview)
            settings.lastStartupSynchronizationAt = Date()
            try database.save(settings: settings)
            try database.insertEvent(type: "Strict startup lock released", message: "Runtime PF anchor synchronized", detail: StartupProtectionService.startupAnchor, succeeded: true)
            await refreshStartupStatus()
        } catch {
            didSynchronizeStrictStartupLockAfterLaunch = false
            try? database.insertEvent(type: "Strict startup lock release failed", message: "Runtime PF anchor synchronization failed", detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
        }
    }

    public func rollbackStartupProtection() async {
        do {
            try await startupProtectionService.rollback()
            settings.startupMode = .monitorOnly
            settings.startupAnchorInstalled = false
            settings.startupRulesLoaded = false
            settings.lastStartupSynchronizationAt = Date()
            try database.save(settings: settings)
            try database.insertEvent(type: "Startup protection disabled", message: "Rolled back startup anchor", detail: StartupProtectionService.startupAnchor, succeeded: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
            reload()
        }
    }

    public func requestLookup(providerID: String? = nil) {
        let provider = providerID ?? settings.defaultLookupProviderID
        switch lookupService.canLookup(ip: liveConnectionsViewModel.selectedConnection?.remote?.address) {
        case let .success(ip):
            pendingLookupIP = ip
            pendingLookupProviderID = provider
            if settings.suppressLookupPrivacyWarning {
                openPendingLookup()
            } else {
                showLookupPrivacyWarning = true
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    public func openPendingLookup(dontShowAgain: Bool = false) {
        guard let ip = pendingLookupIP, let providerID = pendingLookupProviderID else { return }
        do {
            if dontShowAgain {
                settings.suppressLookupPrivacyWarning = true
                try database.save(settings: settings)
            }
            try lookupService.open(ip: ip, providerID: providerID)
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingLookupIP = nil
        pendingLookupProviderID = nil
        showLookupPrivacyWarning = false
    }

    public func cancelPendingLookup() {
        pendingLookupIP = nil
        pendingLookupProviderID = nil
        showLookupPrivacyWarning = false
    }

    public func copySelectedRemoteIP() {
        guard let ip = liveConnectionsViewModel.selectedConnection?.remote?.address else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
    }

    public func requestTraceroute() {
        switch lookupService.canLookup(ip: liveConnectionsViewModel.selectedConnection?.remote?.address) {
        case .success:
            if settings.suppressTracerouteWarning {
                runNetworkTool(.traceroute)
            } else {
                showTracerouteWarning = true
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    public func confirmTraceroute(dontShowAgain: Bool = false) {
        if dontShowAgain {
            settings.suppressTracerouteWarning = true
            try? database.save(settings: settings)
        }
        showTracerouteWarning = false
        runNetworkTool(.traceroute)
    }

    public func runNetworkTool(_ kind: NetworkToolKind) {
        guard let ip = liveConnectionsViewModel.selectedConnection?.remote?.address else {
            errorMessage = "No remote IP is available for the selected connection."
            return
        }
        guard !isNetworkToolRunning else { return }
        networkToolOutput = ""
        isNetworkToolRunning = true
        Task {
            do {
                try await networkToolRunner.run(kind: kind, ip: ip) { [weak self] text in
                    Task { @MainActor in
                        self?.networkToolOutput += text
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isNetworkToolRunning = false
            }
        }
    }

    public func stopNetworkTool() {
        networkToolRunner.stop()
        isNetworkToolRunning = false
    }

    public func copyNetworkToolOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(networkToolOutput, forType: .string)
    }

    public func saveNetworkToolOutput() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "network-tool-output.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try networkToolOutput.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func importCountryList(url: URL, countryCode: String, countryName: String, sourceName: String, notes: String = "") {
        countryImportProgress = "Importing \(countryCode.uppercased())..."
        Task {
            do {
                let result = try await GeoBlockImportService().importFile(
                    url: url,
                    countryCode: countryCode,
                    countryName: countryName,
                    sourceName: sourceName,
                    notes: notes,
                    database: database
                )
                await MainActor.run {
                    countryImportProgress = nil
                    importWarnings = result.warnings
                    reload()
                }
            } catch {
                await MainActor.run {
                    countryImportProgress = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func importIPDenyCountries(_ countries: [CountryCatalogEntry], includeIPv4: Bool, includeIPv6: Bool) {
        guard !countries.isEmpty, includeIPv4 || includeIPv6 else { return }
        let versions: [IPVersion] = [includeIPv4 ? .ipv4 : nil, includeIPv6 ? .ipv6 : nil].compactMap { $0 }
        countryImportProgress = "Preparing \(countries.count) countr\(countries.count == 1 ? "y" : "ies")..."
        Task {
            var warnings: [String] = []
            var failures: [String] = []
            let source = IPDenyCountrySource()
            let importer = GeoBlockImportService()
            let total = countries.count * versions.count
            var completed = 0
            for country in countries {
                for version in versions {
                    countryImportProgress = "Downloading \(country.name) \(version.rawValue) (\(completed + 1) of \(total))..."
                    do {
                        let text = try await source.download(countryCode: country.code, version: version)
                        let result = try await importer.importText(
                            text,
                            countryCode: country.code,
                            countryName: country.name,
                            sourceName: "IPdeny \(version.rawValue) aggregated",
                            notes: "Country allocation ranges imported from IPdeny",
                            database: database
                        )
                        warnings.append(contentsOf: result.warnings)
                    } catch {
                        failures.append("\(country.name) \(version.rawValue): \(error.localizedDescription)")
                    }
                    completed += 1
                }
            }
            countryImportProgress = nil
            importWarnings = Array(Set(warnings)).sorted()
            if !failures.isEmpty {
                errorMessage = "Some country lists could not be imported: \(failures.prefix(3).joined(separator: "; "))"
            }
            reload()
        }
    }

    public func setGeoCountryEnabled(code: String, enabled: Bool) {
        do {
            try database.setGeoCountryEnabled(code: code, enabled: enabled)
            try database.insertEvent(type: enabled ? "Country block enabled" : "Country block disabled", message: code.uppercased(), detail: "", succeeded: true)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setGeoCountryDirection(code: String, direction: FirewallDirection) {
        do {
            try database.setGeoCountryDirection(code: code, direction: direction)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setGeoCountryNotes(code: String, notes: String) {
        do {
            try database.setGeoCountryNotes(code: code, notes: notes)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func simulateGeoImpact() {
        let simulator = GeoBlockSimulationService()
        geoSimulation = simulator.simulate(
            countries: geoCountries.filter(\.isEnabled),
            ranges: geoRanges.filter(\.isEnabled),
            connections: liveConnectionsViewModel.connections,
            allowlist: allowlist
        )
    }

    public func applyRulesIfAllowed() async {
        if settings.confirmBeforeApplying {
            pendingApplyConfirmation = true
            return
        }
        await applyRules()
    }

    public func applyRules() async {
        do {
            try database.insertEvent(type: "PF reload attempted", message: "Applying app anchor", detail: settings.anchorPath, succeeded: true)
            try await firewallService.apply(anchorText: rulePreview, settings: settings)
            try database.insertEvent(type: "PF reload succeeded", message: "Applied app anchor", detail: settings.anchorName, succeeded: true)
            reload()
        } catch {
            try? database.insertEvent(type: "PF reload failed", message: "Could not apply app anchor", detail: error.localizedDescription, succeeded: false)
            errorMessage = error.localizedDescription
            reload()
        }
    }

    private func rebuildPreview() {
        rulePreview = generator.rules(for: currentRules(), allowlist: allowlist, settings: settings)
    }

    private func currentRules() -> [BlockRule] {
        let manual = manualBlocks.map {
            BlockRule(group: .manualBlocks, value: $0.address, direction: $0.direction, source: $0.source, note: $0.note, isEnabled: $0.isEnabled)
        }
        let importedBlocklists = Set(blocklists.filter(\.isEnabled).map(\.id))
        let imported = blocklistEntries.filter { importedBlocklists.contains($0.blocklistID) && $0.isEnabled }.map {
            BlockRule(group: .importedBlocklists, value: $0.value, direction: .both, source: .imported, note: $0.warning ?? "", isEnabled: $0.isEnabled)
        }
        let enabledCountries = Dictionary(uniqueKeysWithValues: geoCountries.filter(\.isEnabled).map { ($0.countryCode, $0) })
        let geo = geoRanges.compactMap { range -> BlockRule? in
            guard range.isEnabled, let country = enabledCountries[range.countryCode] else { return nil }
            return BlockRule(group: .importedBlocklists, value: range.cidr, direction: country.direction, source: .imported, note: "Geo block \(country.countryCode): \(country.notes)", isEnabled: true)
        }
        return manual + imported + geo + reputationMatchedConnectionRules()
    }

    private func reputationMatchedConnectionRules() -> [BlockRule] {
        guard settings.blockReputationMatchedConnections else { return [] }
        let matched = liveConnectionsViewModel.connections.compactMap { connection -> BlockRule? in
            guard let remoteIP = connection.remote?.address, !remoteIP.isEmpty else { return nil }
            let matches = reputationStore.matches(for: connection)
            guard !matches.isEmpty else { return nil }
            let lists = Set(matches.map(\.listName)).sorted().joined(separator: ", ")
            return BlockRule(
                group: .importedBlocklists,
                value: remoteIP,
                direction: .both,
                source: .imported,
                note: "Matched enabled reputation block list: \(lists)",
                isEnabled: true
            )
        }
        var seen = Set<String>()
        return matched.filter { seen.insert($0.value).inserted }
    }

    private func rebuildSnapshot() {
        let connections = liveConnectionsViewModel.connections
        let remoteCounts = Dictionary(grouping: connections.compactMap(\.remote?.address), by: { $0 }).mapValues(\.count)
        let processCounts = Dictionary(grouping: connections.map(\.processName), by: { $0 }).mapValues(\.count)
        let hourAgo = Date().addingTimeInterval(-3600)
        snapshot = FirewallDashboardSnapshot(
            activeConnections: connections.count,
            blockedIPs: manualBlocks.filter(\.isEnabled).count + blocklistEntries.filter(\.isEnabled).count,
            loadedBlocklists: blocklists.count,
            blocksInLastHour: events.filter { $0.date >= hourAgo && $0.eventType.localizedCaseInsensitiveContains("block") }.count,
            topRemoteIPs: remoteCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) },
            topProcesses: processCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) },
            pfStatus: startupStatus.pfEnabled,
            lastRuleReload: events.first { $0.eventType == "PF reload succeeded" }?.date
        )
    }
}

public enum FirewallSection: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "Dashboard"
    case liveConnections = "Live Connections"
    case applications = "Applications"
    case timeline = "Timeline"
    case intelligence = "Intelligence"
    case internetWeather = "Internet Weather"
    case alerts = "Alerts"
    case enrichment = "Enrichment"
    case investigations = "Investigations"
    case visuals = "Visuals"
    case extensions = "Extensions"
    case blockedIPs = "Blocked IPs"
    case blocklists = "Blocklists"
    case countryBlocking = "Country Blocking"
    case rules = "Rules"
    case logs = "Logs"
    case nmapWorkbench = "Nmap Workbench"
    case settings = "Settings"
    case about = "About"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .liveConnections: "network"
        case .applications: "app.connected.to.app.below.fill"
        case .timeline: "timeline.selection"
        case .intelligence: "brain.head.profile"
        case .internetWeather: "cloud.sun"
        case .alerts: "exclamationmark.triangle"
        case .enrichment: "sparkle.magnifyingglass"
        case .investigations: "eye.circle"
        case .visuals: "point.3.connected.trianglepath.dotted"
        case .extensions: "puzzlepiece.extension"
        case .blockedIPs: "shield"
        case .blocklists: "list.bullet.rectangle"
        case .countryBlocking: "globe"
        case .rules: "curlybraces.square"
        case .logs: "doc.text.magnifyingglass"
        case .nmapWorkbench: "dot.radiowaves.left.and.right"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
