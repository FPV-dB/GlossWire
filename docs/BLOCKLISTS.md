# GlossWire Blocklists And Provider Feeds

## Principles

Blocklists are indicators, not proof. Addresses change ownership, shared hosting creates collateral damage, and large lists can consume memory or produce costly PF rules. GlossWire therefore keeps optional catalogues disabled by default and exposes generated rules before application.

## Local Import Formats

Supported inputs include plain text, `.ip`, `.list`, and simple CSV files. The parser:

- Ignores blank lines and lines beginning with `#` or `;`.
- Uses the first CSV column.
- Accepts IPv4/IPv6 addresses and CIDRs where supported.
- Deduplicates entries.
- Skips invalid entries and reports counts.
- Refuses unsafe special ranges and warns about private LAN ranges.

## Built-In Reputation Sources

The catalogue includes separately labelled feeds for advertising/privacy filters and security indicators, including EasyList-family sources, Peter Lowe, uBlock assets, URLHaus, Spamhaus DROP, DShield, Feodo Tracker, FireHOL IPsum, CINS Army, Binary Defense Artillery, and Bitwire IT malicious outbound destinations.

Licensing and provider terms remain the responsibility of each upstream source. Optional feeds are disabled by default unless explicitly identified otherwise in the UI.

## FireHOL Catalogue

GlossWire retrieves FireHOL's current summary and repository tree, then presents compatible root-level `.ipset` and `.netset` files as independent subscriptions. Entries are grouped by category and show the upstream maintainer and approximate unique IPv4 count. Incompatible or unresolved files are omitted rather than assigned guessed URLs.

Large catalogues should be enabled selectively. Loading every list increases download volume, memory use, overlap, and false-positive risk.

## Live Reputation Matches

Enabled local lists can be matched against remote addresses observed in Live Connections. Matches are informational unless **Block live connections that match enabled Block Lists** is enabled. When enabled, matched remote IPs are deduplicated and added to the generated preview; administrator-approved application is still required.

## Managed Provider Feeds

- **Google and Google Cloud:** official `goog.json` and `cloud.json` feeds.
- **Microsoft and Azure:** Microsoft's public Azure Service Tags document.
- **Tor:** Tor Project Onionoo catalogue of currently running public relays.
- **Countries:** searchable IPv4/IPv6 allocation lists from IPdeny, plus manual imports.

Provider and country ranges are not threat feeds. They are broad ownership/allocation controls and may block customer-hosted cloud services, CDNs, authentication, updates, APIs, VPN endpoints, and unrelated users.

## Direction Matters

An inbound scanner list should not automatically become an outbound destination list. Conversely, a malware command-and-control destination feed is most useful outbound. Confirm the publisher's intended direction before importing or generating PF rules.

## Safe Evaluation Checklist

Before enabling a new source, verify:

1. Upstream provenance and maintainer identity.
2. Declared license and redistribution terms.
3. Last successful update and expected cadence.
4. Intended traffic direction.
5. Entry count and aggregate address coverage.
6. Presence of private, loopback, multicast, documentation, or enormous catch-all ranges.
7. Overlap with existing enabled feeds.
8. Recovery access through **Stop All Blocking**.

Avoid old “mega lists” with no methodology. A list that blocks a material fraction of the IPv4 internet is more likely to break essential services than provide precise protection.

![Blocklist match and PF preview](screenshots/reputation-filter-options-redacted.png)
