# Contributing To GlossWire

Thank you for improving GlossWire. Changes should preserve its defensive, local-first scope and explicit administrator-confirmation model.

## Before Opening A Change

- Keep unrelated workspace changes out of the commit.
- Do not commit live IP addresses, hostnames, process names, logs, databases, scan results, credentials, API keys, or local paths.
- Use documentation ranges such as `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24` in examples.
- Keep optional blocking features disabled by default unless a migration and safety case is documented.
- Do not broaden app-managed PF operations to flush or replace unrelated system rules.

## Verification

Run:

```sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build-app.sh
codesign --verify --deep --strict build/GlossWire.app
```

Add focused tests for parsing, persistence, rule ordering, failure recovery, and migrations affected by the change.

## Documentation

Update the relevant guide under `docs/` for user-visible behavior. Screenshots must be synthetic or redacted and must not expose private endpoints, processes, account information, timestamps, identifiers, or filesystem paths.

## Pull Requests

Describe:

1. The user-visible outcome.
2. Security and privacy impact.
3. PF anchor or persistence changes.
4. Tests and local build evidence.
5. Recovery behavior if the feature can interrupt connectivity.
