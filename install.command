#!/bin/bash
set -euo pipefail

# Requires Xcode (full) for xcodebuild.
# Install from the Mac App Store or: xcode-select --install (CLT only — not sufficient for xcodebuild)
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: 'xcodebuild' not found."
  echo "Install Xcode from the Mac App Store, then run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Error: No active developer directory found."
  echo "Run: sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CoverUp"
SCHEME="CoverUp"
DERIVED="$ROOT/.build"
BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/$APP_NAME.app"

# ---------------------------------------------------------------------------
# Build app icon from assets/coverup-logo.png
# ---------------------------------------------------------------------------
LOGO="$ROOT/assets/coverup-logo.png"
ICONSET_DIR="$ROOT/Sources/CoverUp/Assets.xcassets/AppIcon.appiconset"

if [ -f "$LOGO" ]; then
  echo "Generating app icon from $LOGO..."
  for size in 16 32 64 128 256 512 1024; do
    sips -z "$size" "$size" "$LOGO" --out "$ICONSET_DIR/Icon-${size}.png" >/dev/null
  done
  echo "App icon generated."
else
  echo "Warning: $LOGO not found — skipping icon generation."
fi
# ---------------------------------------------------------------------------

echo "Building $APP_NAME (Release)..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

if [ ! -d "$BUILT_APP" ]; then
  echo "Error: Build succeeded but app bundle not found at: $BUILT_APP"
  exit 1
fi

echo "Installing to ${DEST_APP}..."
mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"

# Reset TCC permissions so macOS re-prompts on next launch.
echo "Resetting existing permissions for com.namuan.coverup..."
tccutil reset ScreenCapture com.namuan.coverup 2>/dev/null || true
tccutil reset Accessibility com.namuan.coverup 2>/dev/null || true
echo "Permissions reset."

mv "$BUILT_APP" "$DEST_APP"

echo "Done."
open "$DEST_APP"
