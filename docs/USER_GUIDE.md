# Connection Manager User Guide

Connection Manager is a defensive macOS utility for network visibility and deliberate PF firewall rule management. It is built for reviewing local connections, understanding which apps are active on the network, and applying app-managed block rules only after user review.

## First Launch

1. Launch `Live Connections Monitor.app`.
2. Open the main window from the menu bar item if it is not already visible.
3. Review the Dashboard and Live Connections views.
4. Visit Settings before enabling any firewall features.

Closing the main window hides it. The app continues running from the menu bar.

## Dashboard

The Dashboard summarizes the app's monitoring and firewall state. Use it to confirm whether the app is monitoring only, whether PF rules are loaded, and whether recent rule or data events need attention.

## Live Connections

The Live Connections view shows observed TCP and UDP activity from standard macOS tools. Rows are deduplicated by protocol, local endpoint, remote endpoint, and process ID.

Use this view to:

- See active remote endpoints.
- Identify the local process associated with a connection.
- Select a row for more details.
- Open explicit GeoIP or reputation lookups for public remote IPs.
- Run optional ping or traceroute actions for a selected public endpoint.

Private, local, multicast, broadcast, unspecified, and empty addresses are blocked from lookup and diagnostic actions.

## Applications

The Applications view groups observed activity by process or app. Use it when you want a process-centered view instead of a connection-centered view.

Useful questions:

- Which app is currently active on the network?
- Which app was seen most recently?
- Which remote endpoints are associated with this process?

## Blocked IPs

Manual IP and CIDR blocks are user-managed entries. Review entries carefully before applying generated PF rules.

Connection Manager validates addresses and refuses dangerous or nonsensical targets such as loopback, unspecified, broadcast, and multicast ranges.

## Blocklists

Blocklist imports support simple text, IP list, and CSV-style files. The importer:

- Ignores blank lines.
- Ignores comments.
- Accepts IPv4, IPv4 CIDR, IPv6, and IPv6 CIDR where practical.
- Skips invalid entries.
- Deduplicates repeated entries.
- Warns on private LAN ranges.

Always review the generated summary before applying imported entries.

### Reputation-Matched Live Connection Blocking

Enabled blocklists are checked locally against observed live connection remote IPs. Matches are informational unless Settings > Firewall > Block live connections that match enabled Block Lists is enabled.

When enabled, matching live connection remote IPs are added to the generated app-managed PF rule preview. They are not silently enforced. Review generated PF rules and apply the app-managed anchor before treating rules as active.

![Reputation filter options and generated rule preview](screenshots/reputation-filter-options-redacted.png)

## Country Blocking

Country blocking is opt-in. The app does not bundle proprietary GeoIP data. Users may import country range files they are licensed or permitted to use.

Country-level IP blocking is broad and can break legitimate sites, CDNs, APIs, software updates, cloud services, and game servers. Use the simulation and preview panels before applying rules.

## Rules

The Rules view previews generated PF rules before they are applied. This is the final review point before administrator approval.

Connection Manager writes app-managed anchors rather than editing unrelated PF anchors.

## Logs

Logs provide an audit trail for firewall changes and app events. Use them to understand what was imported, generated, applied, or rolled back.

## Settings

Settings include:

- Menu bar throughput display.
- Rate units and update intervals.
- Start Connection Manager at startup using the macOS login item service.
- Data Milestone Sounds.
- GeoIP and reputation lookup provider options.
- Firewall and persistence options.
- Optional blocking for live connections that match enabled local blocklists.

If the startup status says approval is required, enable Connection Manager in System Settings > Login Items.

Startup protection can affect connectivity. Read the confirmation text carefully before enabling strict modes.

## Safe Operating Model

Connection Manager is designed around review and confirmation:

1. Observe network activity.
2. Add manual or imported rules.
3. Simulate and preview generated rules.
4. Approve administrator actions only when the rules are expected.
5. Review logs after changes.

## Recovery

If firewall rules cause unexpected network behavior:

1. Open Connection Manager and roll back app-managed rules.
2. Disable startup protection if enabled.
3. Review `/etc/pf.anchors/com.connectionmanager.*` anchors if manual cleanup is required.
4. Reboot if PF state needs to be reset after manual changes.

## What Connection Manager Is Not

Connection Manager is not a packet sniffer, MITM proxy, credential tool, exploit tool, stealth monitor, or kernel extension. It is a defensive local utility for visibility, rule generation, and deliberate firewall management.
