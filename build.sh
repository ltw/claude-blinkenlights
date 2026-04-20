#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

command -v swift >/dev/null || { echo "swift not found: install Xcode or the Swift toolchain"; exit 1; }
command -v jq    >/dev/null || { echo "jq not found: brew install jq"; exit 1; }

APP="ClaudeBlinkenlights.app"
BIN=".build/release/ClaudeBlinkenlights"

rm -rf "$APP"
swift build -c release

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/hooks"
cp "$BIN"              "$APP/Contents/MacOS/ClaudeBlinkenlights"
cp Info.plist          "$APP/Contents/Info.plist"
cp hooks/*.sh          "$APP/Contents/Resources/hooks/"
chmod +x "$APP/Contents/Resources/hooks/"*.sh

echo "Built $APP"
echo "Drag it to /Applications and launch. Hooks install on first run."
