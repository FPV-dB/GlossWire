# GlossWire User Guide

GlossWire is a defensive macOS utility for network visibility and deliberate PF firewall rule management. It is built for reviewing local connections, understanding which apps are active on the network, and applying app-managed block rules only after user review.

## First Launch

1. Launch `GlossWire.app`.
2. Open the main window from the menu bar item if it is not already visible.
3. Review the Dashboard and Live Connections views.
4. Visit Settings before enabling any firewall features.

Closing the main window hides it. The app continues running from the menu bar. When macOS launches GlossWire as a login item, the main window stays hidden automatically; choose **Show Connections** from the menu bar popover whenever you want to open it. Launching the app yourself from Finder or Applications still opens the window normally.

## Desktop Throughput Bar

Enable **Show transparent throughput bar on the desktop** in Settings > Desktop Throughput Bar to display a compact glass overlay containing the real download rate, upload rate, and recent activity graph. Use the opacity slider to adjust the complete overlay from 25% to 100%. Drag the bar to reposition it; its position is remembered. It appears across Spaces and stays above ordinary windows. Hover over it and use the close button to hide it, or disable it from Settings. The desktop bar is disabled by default and does not alter or simulate traffic.

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

### Nmap for a Selected IP

Select a connection and use the Nmap menu in the toolbar or inspector for a Quick Port, Service/Version, or OS Detection scan. The row context menu offers the same actions. Results open in the existing Nmap workbench, where they can be stopped, reviewed, compared with history, or exported. The full workbench is prefilled with the selected remote IP. Nmap scanning is restricted to local/private targets by the app's existing target safety check.

## Applications

The Applications view groups observed activity by process or app. Use it when you want a process-centered view instead of a connection-centered view.

Useful questions:

- Which app is currently active on the network?
- Which app was seen most recently?
- Which remote endpoints are associated with this process?

## Blocked IPs

Manual IP and CIDR blocks are user-managed entries. Review entries carefully before applying generated PF rules.

GlossWire validates addresses and refuses dangerous or nonsensical targets such as loopback, unspecified, broadcast, and multicast ranges.

## Blocklists

The optional **Bitwire IT · Malicious Outbound Destinations** subscription is a separately labelled, disabled-by-default feed for malicious destinations, command-and-control, botnet, and malware infrastructure. Its source list is maintained by Bitwire IT and licensed CC BY-NC-SA 4.0. The much larger inbound list is not imported into the current PF rule engine because millions of individual entries would make rule generation and application impractical.

Near the top of **Settings → Firewall**, **Block known public Tor relays and exits** downloads the Tor Project's current Onionoo public-relay catalogue. GlossWire asks for confirmation before enabling it and lets you refresh the catalogue later. It helps block direct Tor and `.onion` use, but Tor bridges and other proxies can bypass IP-only filtering.

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

Public IP reputation subscriptions are optional and disabled by default. They can produce false positives, especially aggregate lists and volatile attacker-subnet feeds. Review the source, count, and generated PF rules before enabling enforcement.

Use **Block all lists** on the Block Lists settings page only when you want every subscription selected. It does not silently apply PF rules; enforcement still requires the Firewall option to block reputation matches and an applied app-managed PF anchor.

The Block Lists page also loads FireHOL's monitored catalogue. Every compatible FireHOL `.ipset` or `.netset` is presented as a separate, labelled subscription grouped by its source category. These catalogue entries are disabled by default. Lists without a compatible downloadable copy are omitted rather than assigned a guessed URL.

![Reputation filter options and generated rule preview](screenshots/reputation-filter-options-redacted.png)

## Country Blocking

Country blocking is opt-in. Choose **Choose Countries** to open the searchable country catalogue, then select one or more countries and the IPv4 and/or IPv6 address families. GlossWire downloads aggregated CIDR allocation lists from IPdeny. New imports remain disabled until you review and enable each country in the Country Blocking table. Existing countries are marked in the chooser and can be refreshed by importing them again.

The manual importer remains available for country range files from other sources that you are licensed or permitted to use.

Country-level IP blocking is broad and can break legitimate sites, CDNs, APIs, software updates, cloud services, and game servers. Use the simulation and preview panels before applying rules.

## Rules

The Rules view previews generated PF rules before they are applied. This is the final review point before administrator approval.

GlossWire writes app-managed anchors rather than editing unrelated PF anchors.

## Logs

Logs provide an audit trail for firewall changes and app events. Use them to understand what was imported, generated, applied, or rolled back.

## Settings

Settings include:

- Menu bar throughput display.
- Rate units and update intervals.
- Start GlossWire at startup using the macOS login item service.
- Data Milestone Sounds.
- GeoIP and reputation lookup provider options.
- Firewall and persistence options.
- Optional blocking for live connections that match enabled local blocklists.
- Optional public reputation feeds for Spamhaus DROP, DShield, abuse.ch Feodo Tracker, FireHOL IPsum, CINS Army, Binary Defense Artillery, and Bitwire IT malicious outbound destinations.
- Broad provider blocking presets for Google/Google Cloud and Microsoft/Azure published IP ranges.

If the startup status says approval is required, enable GlossWire in System Settings > Login Items.

If **PF Enabled** shows **Administrator check required**, use **Check Status** to perform an authenticated status query or **Enable PF** to enable the macOS packet filter from GlossWire. Both actions use the standard macOS administrator prompt. Enabling PF does not by itself apply the generated GlossWire anchor; review and apply rules separately.

Login-item launches run quietly: monitoring and the menu bar item start, but the main window stays hidden. Open it with **Show Connections** in the menu bar popover. A normal manual launch opens the main window.

When startup launch is enabled and no startup protection mode is already selected, GlossWire selects Strict Startup Lock and asks for administrator approval to install the startup PF anchor. Strict Startup Lock also installs a root LaunchDaemon that reloads the startup PF anchor after reboot, because PF runtime anchors do not persist by themselves. This startup anchor blocks all non-loopback traffic until GlossWire starts. Once the app is running, it synchronizes the live PF startup anchor with the normal generated app rules while keeping the strict startup anchor on disk for the next boot.

Startup protection can affect connectivity. Read the confirmation text carefully before enabling strict modes.

### Texture Overlays

Settings > Visual Appearance includes optional Fine Grain, Dot Grid, Diagonal Weave, Technical Grid, and Circuit Traces overlays with adjustable intensity. These code-rendered textures are visual only, do not intercept clicks, and do not affect monitoring or firewall rules. Choose None to remove the overlay.

## Safe Operating Model

GlossWire is designed around review and confirmation:

1. Observe network activity.
2. Add manual or imported rules.
3. Simulate and preview generated rules.
4. Approve administrator actions only when the rules are expected.
5. Review logs after changes.

## Recovery

If firewall rules cause unexpected network behavior:

1. Open GlossWire and roll back app-managed rules.
2. Disable startup protection if enabled.
3. Review `/etc/pf.anchors/com.connectionmanager.*` anchors if manual cleanup is required.
4. Reboot if PF state needs to be reset after manual changes.

## What GlossWire Is Not

GlossWire is not a packet sniffer, MITM proxy, credential tool, exploit tool, stealth monitor, or kernel extension. It is a defensive local utility for visibility, rule generation, and deliberate firewall management.
