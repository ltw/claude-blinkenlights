#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from Resources/AppIcon.svg.
# Dev-time only; requires rsvg-convert (brew install librsvg). iconutil ships with macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found: brew install librsvg"; exit 1; }
command -v iconutil     >/dev/null || { echo "iconutil not found (macOS-only tool)"; exit 1; }

SVG="Resources/AppIcon.svg"
ICNS="Resources/AppIcon.icns"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

render() {
  local size="$1" name="$2"
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$SET/$name"
}

render 16    icon_16x16.png
render 32    icon_16x16@2x.png
render 32    icon_32x32.png
render 64    icon_32x32@2x.png
render 128   icon_128x128.png
render 256   icon_128x128@2x.png
render 256   icon_256x256.png
render 512   icon_256x256@2x.png
render 512   icon_512x512.png
render 1024  icon_512x512@2x.png

iconutil -c icns "$SET" -o "$ICNS"
echo "Wrote $ICNS"
