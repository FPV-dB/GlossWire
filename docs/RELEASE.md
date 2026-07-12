# GlossWire Release And Hardening Guide

## Local verification

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/verify-release.sh
```

The verifier runs all tests, creates a release bundle, validates `Info.plist`, verifies the deep code signature, confirms required resources, checks screenshot documentation, and rejects bundled SQLite databases or log files.

Versioned builds use:

```bash
GLOSSWIRE_VERSION=1.1.0 GLOSSWIRE_BUILD_NUMBER=42 ./scripts/build-app.sh
```

`GLOSSWIRE_SIGN_IDENTITY` defaults to ad-hoc signing for local development. Set it to an installed Developer ID Application identity for distribution builds.

## Public distribution requirements

These steps require release-owner credentials and are intentionally not automated in the repository:

1. Obtain the Apple Network Extension entitlement before embedding or activating the flow provider.
2. Sign the app and every embedded helper/extension with the correct Developer ID identities and hardened runtime.
3. Submit the final ZIP or DMG with `notarytool`, wait for acceptance, and staple the ticket.
4. Verify with `spctl --assess --type execute --verbose=4` on a clean Mac.
5. Publish checksums and release notes from a protected CI environment.
6. Configure an authenticated, signed update feed before enabling automatic updates. GlossWire currently performs no automatic downloads or installs.

## Security and privacy checks

- `Disable all logs` must stop new application history, firewall events, Nmap history, weather history, alerts, reports, executable baselines, and Time Capsule persistence.
- Plugin executable paths must remain inside their plugin folder and require a stable TeamIdentifier.
- Network Extension capabilities must remain unavailable until the embedded extension is entitled, approved, activated, and connected to the transport.
- No packet payload, credential, MITM, stealth, or kernel-extension behavior may be introduced.
- Firewall recovery controls and the LAN-preserving kill switch must retain their rule-order tests.
- Investigation exports must retain Privacy Mode redaction and `CAPABILITIES.txt` evidence limits.

## Manual user-interface checks

- Launch only `/Applications/GlossWire.app` and confirm the installed executable path.
- Exercise Stop All Blocking, Restore Internet, and kill-switch confirmation without enabling isolation on a remote-support machine.
- Check VoiceOver labels for sidebar navigation, alert actions, retention controls, enrichment fields, and plugin readiness.
- Verify layouts at standard and increased text sizes, high contrast, reduced motion, and Privacy Mode.
- Confirm the menu-bar overlay remains readable on light and dark desktops.
