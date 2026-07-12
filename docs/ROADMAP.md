# GlossWire Feature Roadmap

This roadmap groups proposed features by architectural dependency. It is not a promise that every item will ship unchanged; privacy, macOS platform limits, performance, and false-positive risk take priority.

## Implemented Foundations

- Live process-aware TCP/UDP endpoint monitoring.
- First-seen and last-seen timestamps for live connections.
- Persistent per-application connection history.
- Global Connection Timeline with rolling windows and flight-recorder scrubbing.
- Exportable metadata-only network-session recording.
- Process heatmap, country activity, lifetime histogram, and process/service relationship views.
- Passive hourly **What Changed?** comparisons.
- Observation-only LAN topology with common-service hints.
- Timeline Privacy Mode masking.
- Network Intelligence dashboard with local Journal, application Passports, Network Memory, port analytics, domain-family grouping, and an activity calendar.
- Evidence-based periodic endpoint and IPv6 signals, with honest capability gates for provider-dependent detectors.
- Persistent Timeline bookmarks and two-day retained-metadata comparisons.
- Local Explain My Computer narrative, transparent Internet-behavior ratings, entropy/noise metrics, daily fingerprint similarity, and Quiet Mode.
- Local Internet Weather measurements and persistent ISP-quality history for latency, packet loss, DNS response, routes, and gateway state.
- Persisted, administrator-confirmed Internet Kill Switch with LAN, loopback, multicast, and broadcast preservation plus emergency-pause recovery.
- Auditable ZIP investigation packages with journal, CSV/JSON observations, weather history, bookmarks, privacy redaction, and an evidence-capability manifest.
- Daily and manual Network Time Capsule snapshots covering apps, observed endpoints/LAN devices, Wi-Fi, gateway, routes, quality history, and explicit unavailable-evidence markers.
- Provider-backed executable SHA-256 and signing-team baselines with same-signer update, signer-change, and unsigned/unavailable-signer classification.
- System-context provider for utun VPN/default-route awareness, split-tunnel warnings, session idle time, wake-window activity, and sleep-prevention assertions; DNS leak verdict remains capability-gated when attribution is incomplete.
- Measured process upload-spike signals, retained-observation forecasts, and conventional metadata-based service/ecosystem recognition with per-flow attribution still capability-gated.
- Throughput graphs and per-IP throughput history.
- DNSBL, ASN, RDAP, reverse DNS, Tor checks, and 0–100 IP safety scoring.
- Explicit local/private selected-target Nmap scans with history, comparison, favourites, and export.
- Application icons and signing Team ID where macOS exposes them.
- Plain-English **Why is this connected?** inference from visible metadata.
- Blocklists, country/provider controls, service blocking, and emergency pause/recovery.
- Durable Network Memory tags, notes, trusted-context markers, favourites, and watchlists.

## Phase 2 — Investigation Metadata

- IP first-seen, last-seen, and times-seen aggregation.
- Automatic reverse-DNS enrichment in retained history with caching and expiry.
- Compact WHOIS/RDAP ownership summaries.
- ASN browser that filters current and historical connections.
- Extend Privacy Mode masking to every remaining dashboard, inspector, export, and menu-bar surface.
- Exportable recorded investigation sessions.

## Phase 3 — Change And Baseline Detection

- Longer-baseline **What Changed?** snapshots with configurable comparison windows.
- New executable, destination, country, port, protocol, and IPv6-use alerts.
- Executable signing and hash-change alerts.
- Per-process connection-count and bandwidth baselines.
- Duplicate-alert rate limiting, severity controls, and 24-hour app muting.
- Daily and weekly local reports.

Alerts remain informational by default and must work without GeoIP availability.

## Phase 4 — Visual Investigation

- Interactive bandwidth heatmap by process.
- Country activity timeline.
- Connection lifetime histogram.
- Process tree with inherited network activity.
- Connection relationship grouping.
- Sankey-style process-to-provider view.
- Compact menu-bar health dashboard.

## Phase 5 — Enrichment

- TLS certificate viewer for user-selected endpoints, showing subject, issuer, expiry, fingerprint, negotiated TLS version, and cipher where obtainable without interception.
- Local network topology from passive observations and explicit user-approved discovery.
- Higher-confidence application/service fingerprints with visible evidence and uncertainty labels.

## Long-Term Architecture

- Optional Network Extension provider for reliable per-app flow identity and enforcement.
- Signed module/plugin interfaces with capability declarations and permission boundaries.
- Indexed threat-feed matching for multi-million-entry inbound attack lists.

## Explicitly Excluded From The Current Scope

- Background packet capture or payload retention.
- MITM or TLS certificate interception.
- Credential/session capture.
- Stealth monitoring.
- Kernel extensions.
- Automatic scanning of arbitrary targets.

Packet capture appeared in the idea list, but it conflicts with GlossWire's existing local metadata-only privacy boundary. Reconsidering it would require an explicit product decision, a separate opt-in permission model, strict retention controls, redaction, and new security documentation.
