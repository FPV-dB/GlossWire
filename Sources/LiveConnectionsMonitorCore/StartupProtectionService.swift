import Foundation
import ServiceManagement

public struct LoginItemService: Sendable {
    public init() {}

    public func status() -> String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Disabled"
        case .requiresApproval: return "Requires Approval"
        case .notFound: return "Unavailable"
        @unknown default: return "Unknown"
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

public actor StartupProtectionService {
    public static let startupAnchor = "com.apple/com.connectionmanager.startup"
    public static let rulesAnchor = "com.apple/com.connectionmanager.rules"
    public static let blocklistsAnchor = "com.apple/com.connectionmanager.blocklists"
    public static let startupAnchorPath = "/etc/pf.anchors/com.connectionmanager.startup"
    public static let startupLaunchDaemonPath = "/Library/LaunchDaemons/com.connectionmanager.startup.plist"

    private let runner: CommandRunner

    public init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    public func status(settings: FirewallSettings) async -> StartupProtectionStatus {
        let pf = await pfStatus()
        let installed = FileManager.default.fileExists(atPath: Self.startupAnchorPath)
        return StartupProtectionStatus(
            pfEnabled: pf,
            startupAnchorInstalled: installed || settings.startupAnchorInstalled,
            rulesLoaded: settings.startupRulesLoaded,
            lastSynchronization: settings.lastStartupSynchronizationAt
        )
    }

    public func enablePF() async throws -> String {
        let output = try await runner.runAppleScriptWithAdministratorPrivileges(shellScript: "/sbin/pfctl -e >/dev/null 2>&1 || true; /sbin/pfctl -s info")
        if output.localizedCaseInsensitiveContains("status: enabled") { return "Yes" }
        if output.localizedCaseInsensitiveContains("status: disabled") { return "No" }
        return "Unknown"
    }

    public func privilegedPFStatus() async throws -> String {
        let output = try await runner.runAppleScriptWithAdministratorPrivileges(shellScript: "/sbin/pfctl -s info")
        if output.localizedCaseInsensitiveContains("status: enabled") { return "Yes" }
        if output.localizedCaseInsensitiveContains("status: disabled") { return "No" }
        return "Unknown"
    }

    public func install(mode: StartupProtectionMode, rulePreview: String, backup: Bool) async throws {
        let rules = Self.startupRules(mode: mode, rulePreview: rulePreview)
        let backupCommand = backup ? "if [ -f \"\(Self.startupAnchorPath)\" ]; then /bin/cp \"\(Self.startupAnchorPath)\" \"\(Self.startupAnchorPath).bak.$(/bin/date +%Y%m%d%H%M%S)\"; fi" : ":"
        let script = """
        set -e
        tmp="$(/usr/bin/mktemp)"
        /bin/cat > "$tmp" <<'EOF'
        \(rules)
        EOF
        \(backupCommand)
        /usr/bin/install -m 0644 "$tmp" "\(Self.startupAnchorPath)"
        /bin/rm -f "$tmp"
        \(Self.launchDaemonInstallScript(enabled: mode != .monitorOnly))
        /sbin/pfctl -a "\(Self.startupAnchor)" -f "\(Self.startupAnchorPath)"
        /sbin/pfctl -e >/dev/null 2>&1 || true
        """
        try await runner.runAppleScriptWithAdministratorPrivileges(shellScript: script)
    }

    public func synchronizeRuntimeAfterLaunch(rulePreview: String) async throws {
        let rules = Self.startupRules(mode: .protectionAtBoot, rulePreview: rulePreview)
        let script = """
        set -e
        tmp="$(/usr/bin/mktemp)"
        /bin/cat > "$tmp" <<'EOF'
        \(rules)
        EOF
        /sbin/pfctl -a "\(Self.startupAnchor)" -f "$tmp"
        /bin/rm -f "$tmp"
        /sbin/pfctl -e >/dev/null 2>&1 || true
        """
        try await runner.runAppleScriptWithAdministratorPrivileges(shellScript: script)
    }

    public func rollback() async throws {
        let script = """
        set -e
        /bin/cat > "\(Self.startupAnchorPath)" <<'EOF'
        # Managed by GlossWire.
        # Startup protection disabled.
        EOF
        /bin/rm -f "\(Self.startupLaunchDaemonPath)"
        /bin/launchctl bootout system "\(Self.startupLaunchDaemonPath)" >/dev/null 2>&1 || true
        /sbin/pfctl -a "\(Self.startupAnchor)" -f "\(Self.startupAnchorPath)"
        """
        try await runner.runAppleScriptWithAdministratorPrivileges(shellScript: script)
    }

    public static func startupRules(mode: StartupProtectionMode, rulePreview: String) -> String {
        switch mode {
        case .monitorOnly:
            return """
            # Managed by GlossWire.
            # Monitor Only: no startup PF rules.
            """
        case .protectionAtBoot:
            return """
            # Managed by GlossWire.
            # Startup anchor: \(Self.startupAnchor)
            # Runtime synchronization after GlossWire has started.
            \(rulePreview)
            """
        case .strictStartupLock:
            return """
            # Managed by GlossWire.
            # Strict Startup Lock: advanced mode.
            # Allows local loopback only and blocks all other traffic until rules are synchronized.
            pass quick on lo0 all
            block drop quick all
            """
        }
    }

    private func pfStatus() async -> String {
        guard let result = try? await runner.run("/sbin/pfctl", arguments: ["-s", "info"]) else { return "Unknown" }
        if result.output.localizedCaseInsensitiveContains("status: enabled") { return "Yes" }
        if result.output.localizedCaseInsensitiveContains("status: disabled") { return "No" }
        if result.errorOutput.localizedCaseInsensitiveContains("permission denied") { return "Administrator check required" }
        return "Unknown"
    }

    private static func launchDaemonInstallScript(enabled: Bool) -> String {
        guard enabled else {
            return """
            /bin/rm -f "\(startupLaunchDaemonPath)"
            /bin/launchctl bootout system "\(startupLaunchDaemonPath)" >/dev/null 2>&1 || true
            """
        }
        let command = "/sbin/pfctl -a \(startupAnchor) -f \(startupAnchorPath); /sbin/pfctl -e >/dev/null 2>&1 || true"
        return """
        /bin/cat > "\(startupLaunchDaemonPath)" <<'PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.connectionmanager.startup</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>\(command)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        PLIST
        /usr/sbin/chown root:wheel "\(startupLaunchDaemonPath)"
        /bin/chmod 0644 "\(startupLaunchDaemonPath)"
        /bin/launchctl bootstrap system "\(startupLaunchDaemonPath)" >/dev/null 2>&1 || true
        /bin/launchctl kickstart -k system/com.connectionmanager.startup >/dev/null 2>&1 || true
        """
    }
}
