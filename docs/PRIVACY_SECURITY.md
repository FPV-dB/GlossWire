# GlossWire Privacy And Security Notes

GlossWire is a local defensive network visibility and firewall management app. It is intentionally scoped to user-visible monitoring and user-confirmed PF rule changes.

## Local Data

GlossWire stores firewall and app state locally under Application Support.

Firewall state is stored in SQLite:

```text
~/Library/Application Support/Live Connections Monitor/firewall.sqlite
```

Persisted data may include:

- Manual blocked IPs and CIDRs.
- Imported blocklists and entries.
- Trusted allowlist entries.
- Firewall event logs.
- Settings.
- Whether reputation-matched live connection blocking is enabled.
- Application network history.

Throughput and Data Milestone Sound preferences are stored in `UserDefaults`.

## Network Observation

Live connection monitoring uses standard macOS command-line tools:

```text
/usr/sbin/lsof -i -n -P
/usr/sbin/netstat -anv
```

The app does not capture packet payloads. It observes endpoint and process metadata that macOS exposes through those tools.

## Firewall Changes

GlossWire uses app-managed PF anchors. It does not flush unrelated PF rulesets and does not edit unrelated anchors.

Applying PF rules requires administrator approval. Generated rules should be reviewed before applying them.

## Data Leaving The Machine

GlossWire does not include analytics or telemetry.

Network-related data leaves the machine only when the user explicitly chooses an action that requires it, such as:

- Opening a GeoIP or reputation lookup page for a selected public IP.
- Running ping toward a selected public endpoint.
- Running traceroute toward a selected public endpoint.
- Refreshing externally hosted range feeds such as Google's published IP range documents.

Private, local, multicast, broadcast, unspecified, and empty addresses are refused for lookup and diagnostic actions.

## No Packet Capture Or Interception

GlossWire does not implement:

- Packet capture.
- Man-in-the-middle interception.
- Credential capture.
- Browser cookie or session access.
- Traffic redirection.
- Deauthentication.
- Automatic, background, or unsolicited port scanning. Explicit selected-target Nmap actions are available only after user initiation when Nmap is installed.
- Exploitation.
- Stealth behavior.
- Kernel extensions.

## Blocklist And Country Data

Users are responsible for the blocklist and country-range data they import. Imported data can be overly broad or inaccurate.

Country-level blocking can disrupt legitimate services, including CDNs, cloud services, software updates, game servers, and APIs. Always preview rules and keep recovery access available.

Reputation-matched live connection blocking is opt-in. When enabled, matching observed remote IPs are added to the generated app-managed PF rule preview. Those rules still require the normal review and administrator-approved apply flow before they are active.

## Google Range Blocking

The Google range preset is opt-in and based on Google's published range documents. Blocking those ranges is broad and can disrupt Google Search, Gmail, YouTube, Firebase, Google APIs, reCAPTCHA, Chrome sync, Android services, and customers hosted on Google Cloud.

## Security Posture

The intended security posture is conservative:

1. Show what was observed.
2. Validate user-provided addresses.
3. Preview generated rules.
4. Require administrator approval for PF writes.
5. Keep an audit trail.
6. Provide rollback and recovery paths.

Use GlossWire as a visibility and rule-management tool, not as a substitute for a full enterprise firewall, EDR, or network security platform.
