#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/GlossWire.app"
EXE="$ROOT/.build/arm64-apple-macosx/release/LiveConnectionsMonitor"
VERSION="${GLOSSWIRE_VERSION:-1.0}"
BUILD_NUMBER="${GLOSSWIRE_BUILD_NUMBER:-1}"
SIGN_IDENTITY="${GLOSSWIRE_SIGN_IDENTITY:--}"

cd "$ROOT"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXE" "$APP/Contents/MacOS/LiveConnectionsMonitor"
chmod +x "$APP/Contents/MacOS/LiveConnectionsMonitor"
cp "$ROOT/Resources/ConmagIcon.icns" "$APP/Contents/Resources/ConmagIcon.icns"
cp "$ROOT/Resources/conmag-icon.png" "$APP/Contents/Resources/conmag-icon.png"
printf 'APPL????' > "$APP/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c 'Clear dict' \
  -c 'Add :CFBundleDevelopmentRegion string en' \
  -c 'Add :CFBundleDisplayName string GlossWire' \
  -c 'Add :CFBundleExecutable string LiveConnectionsMonitor' \
  -c 'Add :CFBundleIconFile string ConmagIcon' \
  -c 'Add :CFBundleIdentifier string local.codex.LiveConnectionsMonitor' \
  -c 'Add :CFBundleInfoDictionaryVersion string 6.0' \
  -c 'Add :CFBundleName string GlossWire' \
  -c 'Add :CFBundlePackageType string APPL' \
  -c "Add :CFBundleShortVersionString string $VERSION" \
  -c "Add :CFBundleVersion string $BUILD_NUMBER" \
  -c 'Add :LSApplicationCategoryType string public.app-category.utilities' \
  -c 'Add :LSMinimumSystemVersion string 14.0' \
  -c 'Add :NSPrincipalClass string NSApplication' \
  "$APP/Contents/Info.plist"

codesign --force --deep --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP" >/dev/null
echo "$APP"
