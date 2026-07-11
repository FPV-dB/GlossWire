# GlossWire Development And Architecture

## Repository Layout

```text
Package.swift
Resources/
Sources/LiveConnectionsMonitor/
Sources/LiveConnectionsMonitorCore/
Tests/LiveConnectionsMonitorTests/
docs/
scripts/build-app.sh
```

`LiveConnectionsMonitor` contains the app entry point. Most monitoring, persistence, firewall, blocklist, Nmap, throughput, and SwiftUI feature logic lives in `LiveConnectionsMonitorCore` for testability.

## Compatibility Names

The public product is GlossWire. Several internal identifiers intentionally retain the former project name so existing installations keep their settings and PF state:

```text
Executable: LiveConnectionsMonitor
Bundle ID: local.codex.LiveConnectionsMonitor
Application Support: Live Connections Monitor
PF files and LaunchDaemon: com.connectionmanager.*
```

Do not rename these without a tested migration plan.

## Major Components

- `ConnectionMonitorService` and `ConnectionParser`: `lsof`/`netstat` collection and parsing.
- `FirewallDashboardViewModel`: UI orchestration, rule preview, provider feeds, emergency pause, and audit events.
- `FirewallDatabase`: SQLite-backed firewall settings, lists, rules, and events.
- `FirewallRuleGenerator`: deterministic app-anchor PF text.
- `FirewallBlockService`: administrator-approved runtime anchor write/reload.
- `StartupProtectionService`: startup anchor and LaunchDaemon management.
- `ReputationBlockListStore`: subscription download, parsing, caching, and live matching.
- `ApplicationNetworkDatabase`: separate app-centric network history.
- `NetworkThroughputMonitor`: interface-counter sampling and menu-bar/desktop presentation.
- `NmapScanService` and `NmapScanViewModel`: explicit selected-target scans, parsing, history, comparison, and export.

## Verification

```sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build-app.sh
codesign --verify --deep --strict build/GlossWire.app
```

Tests cover connection parsing, validation, rule ordering, allowlist precedence, strict startup behavior, emergency pause persistence, service-block generation, provider document parsing, blocklist handling, SQLite persistence, throughput formatting, and milestone logic.

## Packaging

`scripts/build-app.sh` performs a release Swift build, assembles `build/GlossWire.app`, copies resources, writes bundle metadata, and applies an ad-hoc signature. It is for local distribution and is not an App Store, Developer ID, notarization, or update-channel pipeline.

## Security Boundaries

- No packet capture or payload inspection.
- No MITM, certificate interception, credential collection, or stealth mode.
- No automatic Nmap execution.
- Firewall mutations remain explicit and administrator-approved.
- Third-party lookups occur only after user action and disclosure.
- App-managed anchors must remain isolated from unrelated PF configuration.

## Documentation Screenshots

Only commit images that exclude or redact private IPs, hostnames, process names, local paths, timestamps, and identifiers. Documentation-safe example ranges such as `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24` are preferred.

![Applications network view](screenshots/applications-network.png)
