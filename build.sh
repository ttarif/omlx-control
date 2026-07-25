#!/bin/bash
# Build oMLX Control and assemble the .app bundle (icon + Info.plist).
#
# Usage:
#   ./build.sh            # build + install to ~/Applications + launch
#   ./build.sh --no-open  # build + install only
set -euo pipefail

APP_NAME="oMLX Control"
APP_DEST="${APP_DEST:-$HOME/Applications/$APP_NAME.app}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Xcode toolchain: SwiftPM's MenuBarExtra/@State macros need a full Xcode
# (not just Command Line Tools). Override with DEVELOPER_DIR if needed.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  for xc in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    [[ -d "$xc" ]] && export DEVELOPER_DIR="$xc/Contents/Developer" && break
  done
fi

echo "Building (release)…"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/oMLXControl"

echo "Assembling bundle at $APP_DEST"
mkdir -p "$APP_DEST/Contents/MacOS" "$APP_DEST/Contents/Resources"
cp "$BIN"                    "$APP_DEST/Contents/MacOS/oMLXControl"
cp "$ROOT/Resources/Info.plist"  "$APP_DEST/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DEST/Contents/Resources/AppIcon.icns"

# Refresh Finder's icon cache for the bundle
touch "$APP_DEST"

if pgrep -x oMLXControl &>/dev/null; then
  pkill -x oMLXControl || true
  sleep 0.5
fi

if [[ "${1:-}" != "--no-open" ]]; then
  echo "Launching…"
  open "$APP_DEST"
fi
echo "Done."
