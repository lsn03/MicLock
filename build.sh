#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="MicLock"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG" --arch arm64

BIN=".build/arm64-apple-macosx/$CONFIG/$APP_NAME"
if [ ! -x "$BIN" ]; then
    echo "Binary not found at $BIN" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN" "$MACOS_DIR/$APP_NAME"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/AppIcon.icns"          "$RES_DIR/AppIcon.icns"
cp "Resources/MicLockTemplate.pdf"   "$RES_DIR/MicLockTemplate.pdf"

# Ad-hoc sign so launchd / SMAppService / tcc are happy.
codesign --force --deep --sign - "$APP_DIR"

echo "✓ Built $APP_DIR"
echo "  Run:  open $APP_DIR"
echo "  Or install:  cp -R $APP_DIR /Applications/"
