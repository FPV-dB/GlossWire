# GlossWire User Guide

GlossWire is a defensive macOS utility for network visibility and deliberate PF firewall rule management. It is built for reviewing local connections, understanding which apps are active on the network, and applying app-managed block rules only after user review.

## First Launch

1. Launch `GlossWire.app`.
2. Open the main window from the menu bar item if it is not already visible.
3. Review the Dashboard and Live Connections views.
4. Visit Settings before enabling any firewall features.

Closing the main window hides it. The app continues running from the menu bar. When macOS launches GlossWire as a login item, the main window stays hidden automatically; choose **Show Connections** from the menu bar popover whenever you want to open it. Launching the app yourself from Finder or Applications still opens the window normally.

The menu-bar popover doubles as a mini dashboard. Alongside current and peak throughput it shows active connections, connections first seen in the last minute, recent blocking/failure events, GlossWire's memory footprint, and system load. Internet latency remains labelled **Not sampled** until the optional Internet Weather sampler is enabled in a later milestone; opening the menu does not generate network probes.

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

Select a row to open **Why is this connected?** in the inspector. GlossWire explains the likely service and application purpose using visible metadata such as process name, direction, protocol, port, and connection state. Explanations are explicitly labelled as inferences: encrypted payloads are not inspected, so the exact application action cannot be proven.

## Connection Timeline And Flight Recorder

The **Timeline** page combines retained application connection records into a single chronological investigation view. It supports:

- Five-minute, 30-minute, one-hour, six-hour, 24-hour, and all-retained windows.
- Search across process identifiers, PIDs, IP addresses, hostnames, ports, countries, states, directions, protocols, and rule outcomes.
- Summary counts for visible records, processes, remote IPs, and countries.
- A flight-recorder scrubber with one-minute back/forward steps.
- **Return to Live** to remove the replay cutoff.
- Configurable display limits up to 25,000 retained rows.

Replay changes the visible historical cutoff; it does not generate network traffic or replay packet payloads. GlossWire stores endpoint and process metadata only.

Use **Record Session** to begin collecting the retained connection observations seen during a troubleshooting interval. **Stop Recording** freezes the session and **Export Session** writes a CSV containing timestamps, process identifiers, endpoints, protocols, durations, states, countries when available, and rule outcomes. The passive provider does not claim DNS- or TLS-handshake events it cannot observe.

The Timeline view selector provides:

- **Heatmap:** process rectangles ranked by observed bandwidth when per-flow bytes are available, otherwise by observation count.
- **Countries:** connection observations grouped by country, with unenriched records labelled Unresolved.
- **Lifetimes:** histogram buckets from sub-second through multi-day connections.
- **Relationships:** process-to-service grouping based on known ports, with destination counts.
- **What Changed?:** compares the current hour with the previous hour for new processes, destinations, ports, disappeared processes, and observation-volume changes.
- **Compare:** selects two calendar days and reports new processes, destinations, countries, ports, and the change in retained observations.
- **Topology:** shows only private LAN devices already present in retained connection observations, with inferred service/device labels. It never initiates a discovery scan.

Enable **Privacy Mode** before presenting or capturing the Timeline. It masks process identifiers, public addresses, hostnames, and paths in supported views without changing stored records.

Use **Bookmark** in the Flight Recorder bar to persist the current replay position. The Bookmarks menu jumps back to saved investigation moments. Comparisons and bookmarks reference retained endpoint history; reducing retention can make an older bookmark fall outside the available record range.

## Network Intelligence

The **Intelligence** page turns retained connection observations into local summaries:

- **Overview:** application Internet-behavior ratings, conventional encrypted-service percentage, destination entropy, background-noise rate, a daily network-fingerprint comparison, Quiet Mode, and **Explain My Computer**.
- **Journal:** a human-readable daily account of observed applications, destinations, ports, and countries.
- **Passports:** first/last seen dates, usual destinations, countries, ports, and observation counts for each process.
- **Network Memory:** accumulated context for each destination, including which processes used it and how often it was observed.
- **Ports:** a ranked chart of observed destination-port usage.
- **Domains:** related hostnames collapsed into domain-family summaries.
- **Calendar:** a day-by-day activity heatmap based on retained observations.
- **Signals:** periodic same-endpoint patterns and IPv6 use derived from retained observations, plus an explicit coverage list for detectors that require richer providers.

Search and Privacy Mode apply to the intelligence views. These summaries describe connection metadata GlossWire has actually retained; they do not inspect payloads, infer packet counts, or claim traffic-byte totals when those measurements are unavailable. Domain-family grouping is a display heuristic and is not a public-suffix classification service.

Periodic signals are behavioral hints, not malware verdicts. Per-flow upload attribution, definitive DNS-leak verdicts, and inbound port-scan detection remain visibly capability-gated until GlossWire has the flow-byte, resolver-attribution, or inbound-attempt telemetry needed to support them accurately.

Process-level **Upload spike** signals use GlossWire's measured upload-rate samples after at least five samples and a 1 MB/s minimum; they do not claim which individual flow carried the bytes. Per-flow attribution remains capability-gated. The Overview activity forecast projects retained connection-observation volume for the day and month and displays its history-based confidence; it is not a bandwidth forecast when byte counters are unavailable.

The **Services** tab recognises conventional hostname, process-name, and port hints for Apple ecosystem traffic, Plex, Jellyfin, Home Assistant, Synology, QNAP, UniFi, Chromecast, Tapo, and DJI. Recognition is a navigational hint rather than deep protocol inspection.

The **Executable Change Detector** in Signals hashes readable executables for running applications and stores their SHA-256 and signing team identifier. Later scans distinguish ordinary same-signer updates from signer changes and unsigned or unavailable-signer replacements. The first scan establishes a baseline and is not an alert. Disable all logs allows a one-time comparison but prevents saving the new baseline.

**System Context** reports VPN services that macOS Network Configuration marks Connected, separately lists `utun` tunnel interfaces, shows the IPv4 default-route interface, session idle time, parsed sleep-prevention assertions, and connection observations made after a wake notification received while GlossWire is running. A default route outside a tunnel while a VPN service is connected is labelled as a possible bypass or intentional split tunnel, not a definite leak. DNS is reported as indeterminate unless macOS exposes enough resolver/interface attribution; GlossWire does not treat ordinary Apple-created `utun` interfaces as proof that a VPN is connected.

Internet ratings measure consistency and observable behavior; they are not reputation verdicts or security certificates. **Explain My Computer** is generated locally from the most recent minute of retained endpoint metadata and does not send data to an AI service. Quiet Mode hides routine rating cards and shows a quiet state when no supported behavior signals are present.

Choose **Export Package** on the Intelligence page to create a ZIP containing a readable summary, Network Journal, connection CSV and JSON, Internet Weather history, Timeline bookmarks, Time Capsule data, and a capability manifest. Privacy Mode redacts supported connection identifiers and Time Capsule network identity details. The manifest records evidence limitations so the package is not mistaken for packet capture or proof that an absent event never occurred.

The **Time Capsule** tab saves at most one automatic snapshot per day while GlossWire is running, with an additional **Capture Now** control. A snapshot records installed application names, observed processes and destinations, passively observed LAN devices, Wi-Fi name, gateway and route availability, recent quality measurements, and the routing table. It explicitly lists unavailable evidence such as process-attributed DNS cache entries and public IP. Disable all logs prevents snapshot persistence. Time Capsule data is included in investigation packages.

## Disable All Logs

In **Settings → Logging and History**, enable **Disable all logs** to immediately stop new firewall event-log rows, application connection-history records, and Nmap scan-history entries. Live monitoring and firewall enforcement continue. Existing records are preserved for review or manual clearing; the toggle does not erase evidence.

## Internet Weather

**Internet Weather** measures three ICMP round trips to `1.1.1.1`, DNS response time for `example.com`, IPv4 and IPv6 default-route availability, and the current IPv4 gateway. Samples are stored locally to build evidence for ISP-quality history; **Disable all logs** prevents new history writes. Failed ICMP or DNS probes can indicate filtering rather than a total outage. GlossWire does not contact a public-IP or ISP-identification API in this mode.

## LAN-Preserving Internet Kill Switch

In **Settings → Firewall**, choose **Isolate from Internet** and confirm the administrator prompt. GlossWire installs ordered `quick` PF rules that permit loopback, RFC 1918 and link-local IPv4, IPv6 ULA and link-local ranges, multicast, and broadcast before blocking remaining inbound and outbound public traffic. This is designed to leave routers, NAS devices, printers, and local discovery reachable. Use **Restore Internet** to remove isolation. If recovery is needed, **Stop All Blocking** overrides the kill switch and empties GlossWire's managed anchors without deleting its saved configuration. Existing stateful connections may take a short time to expire after isolation.

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

The **Service Blocking** section provides independent switches for VNC/Screen Sharing, Apple Remote Desktop administration, Microsoft RDP, SSH/SFTP, Telnet, FTP, SMB, and Windows RPC/NetBIOS. Each switch blocks the service's conventional ports in both directions and updates the generated PF rules. Review and approve the PF apply prompt to activate the change. Custom-port and tunnelled traffic cannot be identified by these port rules.

If GlossWire blocks something essential, select **Settings → Firewall → Stop All Blocking**. Confirm the warning and approve the macOS administrator prompt. GlossWire clears its app-managed and startup PF anchors but retains all saved rules and settings. The orange paused-state banner remains until **Resume Blocking** successfully reapplies them. Unrelated PF anchors are not changed.

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
