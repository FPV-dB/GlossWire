# GlossWire Firewall, Startup Protection, And Recovery

## Safety Model

GlossWire generates and applies rules only to dedicated app-managed PF anchors. It does not flush the global PF ruleset or edit unrelated third-party anchors. Administrator approval is required for privileged writes.

Primary runtime anchor and file:

```text
com.apple/com.connectionmanager.blocked
/etc/pf.anchors/com.connectionmanager.blocked
```

Startup-related anchors:

```text
com.apple/com.connectionmanager.startup
com.apple/com.connectionmanager.rules
com.apple/com.connectionmanager.blocklists
```

The identifiers intentionally retain `connectionmanager` for compatibility with existing installations and saved state.

## Rule Lifecycle

1. Settings, manual blocks, enabled lists, and country/provider selections produce an in-memory rule preview.
2. **Rules** displays the exact PF text.
3. **Apply Anchor** requests administrator approval.
4. GlossWire writes `/etc/pf.anchors/com.connectionmanager.blocked` atomically and reloads only its child anchor.
5. Success or failure is written to the local event log.

Trusted IP/CIDR allowlist passes are generated before ordinary IP block rules. Service-blocking rules are intentionally generated before trusted-IP passes so an allowlisted host cannot bypass a selected VNC, RDP, SSH, or similar port prohibition.

## Service Blocking

Each setting is independent and blocks conventional ports in both directions:

| Toggle | Ports and protocols |
| --- | --- |
| VNC and Screen Sharing | TCP/UDP 5900–5999 |
| Apple Remote Desktop administration | TCP/UDP 3283 |
| Microsoft Remote Desktop | TCP/UDP 3389 |
| SSH and SFTP | TCP 22 |
| Telnet | TCP 23 |
| FTP | TCP 20–21 |
| SMB file sharing | TCP 445 |
| Windows RPC and NetBIOS | TCP/UDP 135 and 137–139 |

Port-based rules cannot identify a protocol moved to a custom port or tunnelled through HTTPS, SSH, a VPN, or another transport.

## Startup Modes

- **Monitor Only** installs no startup firewall rules.
- **Protection at Boot** maintains the configured app rules at startup.
- **Strict Startup Lock** permits loopback only until GlossWire launches and synchronizes the runtime rules.

Strict mode installs a root LaunchDaemon at `/Library/LaunchDaemons/com.connectionmanager.startup.plist`. Incorrect startup rules can interrupt network access after reboot. Keep these recovery steps available offline.

## Stop All Blocking

Use **Settings → Firewall → Stop All Blocking** when an essential site, update, authentication flow, local service, or remote-management path has been blocked.

After confirmation and administrator approval, GlossWire:

- Persists an emergency-paused state.
- Replaces the runtime app anchor with an empty, commented anchor.
- Clears the startup anchor and unloads its LaunchDaemon.
- Preserves every manual rule, blocklist, service toggle, provider toggle, country selection, and startup-mode choice.
- Displays an orange paused-state warning.

The pause survives an app restart. GlossWire does not silently reactivate blocking.

## Resume Blocking

Select **Resume Blocking** and approve the administrator prompt. GlossWire regenerates the saved rule set, applies the runtime anchor, and reinstalls the previously selected startup mode. If restoration fails, the app records the failure and returns to the paused state.

## Recovery When The App Is Available

1. Open the menu-bar popover and select **Show Connections**.
2. Open **Settings → Firewall**.
3. Select **Stop All Blocking**.
4. Review **Logs** for the last successful or failed PF action.
5. Correct the offending list or toggle before resuming.

## Manual Recovery

If GlossWire cannot be opened, an administrator can clear only its anchors from Terminal. Review commands before running them:

```sh
sudo sh -c 'printf "%s\n" "# GlossWire emergency recovery: no runtime rules" > /etc/pf.anchors/com.connectionmanager.blocked'
sudo pfctl -a com.apple/com.connectionmanager.blocked -f /etc/pf.anchors/com.connectionmanager.blocked

sudo sh -c 'printf "%s\n" "# GlossWire startup protection disabled" > /etc/pf.anchors/com.connectionmanager.startup'
sudo pfctl -a com.apple/com.connectionmanager.startup -f /etc/pf.anchors/com.connectionmanager.startup
sudo launchctl bootout system /Library/LaunchDaemons/com.connectionmanager.startup.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.connectionmanager.startup.plist
```

These commands do not disable PF globally and do not touch unrelated anchors.

![Generated rule preview with documentation-safe addresses](screenshots/reputation-filter-options-redacted.png)
