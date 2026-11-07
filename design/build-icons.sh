#!/usr/bin/env bash
set -euo pipefail

# Regenerate Resources/AppIcon.icns and Resources/MicLockTemplate.pdf from
# the chosen SVG concepts. Rerun this whenever you edit the source SVGs.

cd "$(dirname "$0")/.."

APP_SVG="design/concepts/app-C-badge.svg"
TRAY_SVG="design/concepts/tray-C-badge.svg"
ICNS_OUT="Resources/AppIcon.icns"
TRAY_OUT="Resources/MicLockTemplate.pdf"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (brew install librsvg)"; exit 1; }
command -v iconutil     >/dev/null || { echo "iconutil not found"; exit 1; }

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"

render() { rsvg-convert -w "$1" -h "$1" "$APP_SVG" -o "$2"; }

render 16   "$ICONSET/icon_16x16.png"
render 32   "$ICONSET/icon_16x16@2x.png"
render 32   "$ICONSET/icon_32x32.png"
render 64   "$ICONSET/icon_32x32@2x.png"
render 128  "$ICONSET/icon_128x128.png"
render 256  "$ICONSET/icon_128x128@2x.png"
render 256  "$ICONSET/icon_256x256.png"
render 512  "$ICONSET/icon_256x256@2x.png"
render 512  "$ICONSET/icon_512x512.png"
render 1024 "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS_OUT"
echo "✓ $ICNS_OUT"

# Tray template: PDF (vector) so macOS can render crisp at any size + tint it.
rsvg-convert -f pdf "$TRAY_SVG" -o "$TRAY_OUT"
echo "✓ $TRAY_OUT"
