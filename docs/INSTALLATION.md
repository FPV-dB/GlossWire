# GlossWire Installation And First Run

## Requirements

- macOS 14 or later.
- Apple silicon Mac for the current local packaging script.
- Xcode with the Swift toolchain for source builds.
- Administrator approval when enabling PF or applying GlossWire firewall anchors.
- Optional: Nmap for the selected-IP scanning workbench.

GlossWire does not require an account, cloud service, browser extension, kernel extension, or packet-capture permission.

## Build From Source

From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build-app.sh
```

The signed local bundle is produced at `build/GlossWire.app`.

Install it locally:

```sh
pkill -x LiveConnectionsMonitor 2>/dev/null || true
rm -rf "/Applications/GlossWire.app"
ditto "build/GlossWire.app" "/Applications/GlossWire.app"
open "/Applications/GlossWire.app"
```

Replacing the app bundle does not remove databases and preferences stored under the user's Library.

## First Run Checklist

1. Open GlossWire and review **Dashboard** and **Live Connections**.
2. Open **Settings** and choose the monitoring refresh interval.
3. Leave imported feeds, country blocking, provider blocking, service blocking, and startup protection disabled until their impact is understood.
4. Use **Check Status** to query PF status with administrator approval.
5. Use **Enable PF** if PF is disabled. Enabling PF alone does not apply GlossWire's generated rules.
6. Review **Rules** before selecting **Apply Anchor**.
7. Confirm that **Stop All Blocking** is visible before experimenting with broad rules.

## Launch At Login

**Start GlossWire at startup** uses `SMAppService`. macOS may require approval under **System Settings → General → Login Items**. Login-item launches keep the main window hidden; select **Show Connections** from the menu-bar popover to reveal it.

Startup launch and startup firewall protection are separate settings. Read [Firewall, Startup Protection, And Recovery](FIREWALL_AND_RECOVERY.md) before enabling Strict Startup Lock.

## Optional Nmap Installation

The workbench looks for Nmap in common locations or at the custom path set in Settings. With Homebrew:

```sh
brew install nmap
```

Scans are explicit user actions and accept public targets only. GlossWire does not run background or bulk scans.

## Updating

Build a fresh bundle, quit the running executable, replace `/Applications/GlossWire.app`, and relaunch the installed copy. Preserve these locations unless a reset is specifically intended:

```text
~/Library/Application Support/Live Connections Monitor/
~/Library/Preferences/local.codex.LiveConnectionsMonitor.plist
```

## Uninstalling

Before deleting the app, use **Stop All Blocking** or **Rollback Startup Protection** and confirm that the app-managed anchors have been cleared. Then remove `/Applications/GlossWire.app`. Local history and preferences remain until manually removed.

![GlossWire menu-bar throughput popover](screenshots/menu-bar-throughput-popover.png)
