# GlossWire Troubleshooting

## Something Essential Is Blocked

Use **Settings → Firewall → Stop All Blocking** immediately. This clears GlossWire's active runtime and startup anchors while retaining the configuration for diagnosis. See [Firewall And Recovery](FIREWALL_AND_RECOVERY.md).

Likely causes include broad provider/country ranges, an oversized third-party list, a service-blocking toggle, an allowlist that does not cover the required address, or stale cloud/CDN ownership data.

## PF Enabled Shows Administrator Check Required

Reading PF status may require elevation. Select **Check Status** and approve the prompt. If PF is disabled, select **Enable PF**. Enabling PF does not automatically apply the generated GlossWire anchor.

## Rules Appear In Preview But Traffic Is Not Blocked

1. Confirm emergency pause is not active.
2. Select **Apply Anchor** and approve the administrator prompt.
3. Check **Logs** for `PF reload succeeded` or the exact failure.
4. Confirm the relevant list or rule is enabled.
5. Remember that hostname changes, CDN rotation, VPNs, proxies, and custom ports can invalidate IP- or port-specific assumptions.

## Login Item Starts But No Window Appears

This is expected. Login-item launches keep the main window hidden. Select **Show Connections** from the menu-bar popover. Manual Finder launches open the window normally.

## Strict Startup Lock Interrupts Networking

Open GlossWire and select **Stop All Blocking** or **Rollback Startup Protection**. If the app cannot open, use the manual recovery commands in [Firewall And Recovery](FIREWALL_AND_RECOVERY.md).

## Nmap Is Missing

Install it with Homebrew:

```sh
brew install nmap
```

Alternatively, set the exact executable path in Settings. GlossWire refuses local/private/unsafe targets for this public-target workbench.

## Blocklist Download Fails

- Confirm the upstream URL still returns a plain compatible file.
- Check whether the provider requires authentication or changed its terms.
- Retry later for transient rate limiting.
- Use smaller, confidence-ranked lists rather than very large aggregates.
- Inspect the event log and parser warning counts.

## High CPU Or Memory

- Increase the live refresh interval.
- Disable unused FireHOL subscriptions.
- Avoid enabling every large list simultaneously.
- Hide optional sparklines or texture overlays.
- Close the Nmap workbench when unused and prune old scan history.

## Build Fails With BuildServerProtocol.framework

Use the full Xcode developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Build Fails With No Space Left On Device

Swift's debug index can require hundreds of megabytes. Remove reproducible local build products and retry:

```sh
rm -rf .build build
```

Do not remove `~/Library/Application Support/Live Connections Monitor` unless a full data reset is intended.

![Live Connections with private rows removed](screenshots/live-connections.png)
