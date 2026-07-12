#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/GlossWire.app}"

cd "$ROOT"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" swift test
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" "$ROOT/scripts/build-app.sh" >/dev/null

test -d "$APP"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"
test -x "$APP/Contents/MacOS/LiveConnectionsMonitor"
test -f "$APP/Contents/Resources/ConmagIcon.icns"
test -f "$ROOT/docs/screenshots/glosswire-dashboard.png"

if find "$APP" \( -name '*.sqlite' -o -name '*.log' \) | grep -q .; then
  echo "Runtime logs or databases must not be shipped inside the app bundle." >&2
  exit 1
fi

IDENTITY="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
if [[ -z "$IDENTITY" || "$IDENTITY" == "adhoc" ]]; then
  echo "Local verification passed. Developer ID signing and notarization remain required for public distribution."
else
  echo "Signed release candidate verified with: $IDENTITY"
fi
