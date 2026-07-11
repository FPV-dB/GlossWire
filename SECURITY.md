# GlossWire Security Policy

## Reporting A Vulnerability

Please use GitHub's private vulnerability reporting or security-advisory interface for the repository when available. Do not post credentials, private IP addresses, live firewall configurations, or exploit details in a public issue.

Include the affected commit or version, macOS version, reproduction steps using documentation-safe values, expected behavior, observed behavior, and whether administrator approval or PF state is involved.

## Scope

Security-sensitive areas include:

- Privileged PF anchor writes and reloads.
- Startup LaunchDaemon installation and rollback.
- Emergency blocking pause and recovery.
- Rule ordering and allowlist precedence.
- Blocklist parsing and unsafe-range validation.
- External URL/feed handling.
- Nmap argument validation and process execution.
- Local SQLite and preference storage.

## Defensive Boundaries

GlossWire must not add packet interception, credential collection, stealth monitoring, exploit delivery, deauthentication, certificate interception, or unapproved background scanning. New network actions should be visible, deliberate, narrowly scoped, and documented.

## Sensitive Diagnostics

Before sharing logs or screenshots, remove IP addresses, hostnames, process names, usernames, local paths, database contents, timestamps, device identifiers, API keys, and scan output that could identify a system or network.
