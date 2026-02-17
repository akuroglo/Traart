#!/bin/bash
# Create DMG installer for Traart distribution
# Usage: ./scripts/create-dmg.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Traart.app"
DMG_PATH="$BUILD_DIR/Traart.dmg"
DMG_VOLUME_NAME="Traart"
TMP_DMG_DIR="$BUILD_DIR/dmg-staging"

echo "=== Traart DMG Creator ==="

# Check that .app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: Traart.app not found at $APP_BUNDLE"
    echo "Run ./scripts/build.sh first."
    exit 1
fi

# Check that the binary exists inside the bundle
if [ ! -f "$APP_BUNDLE/Contents/MacOS/TraartApp" ]; then
    echo "ERROR: Binary not found inside Traart.app bundle."
    echo "Run ./scripts/build.sh to rebuild."
    exit 1
fi

# Clean previous DMG artifacts
if [ -f "$DMG_PATH" ]; then
    echo "Removing previous DMG..."
    rm -f "$DMG_PATH"
fi
if [ -d "$TMP_DMG_DIR" ]; then
    rm -rf "$TMP_DMG_DIR"
fi

# Create staging directory
echo "Creating staging directory..."
mkdir -p "$TMP_DMG_DIR"

# Copy .app bundle
echo "Copying Traart.app..."
cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$TMP_DMG_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" 2>&1

# Clean up staging directory
echo "Cleaning up..."
rm -rf "$TMP_DMG_DIR"

# Verify
if [ -f "$DMG_PATH" ]; then
    echo ""
    echo "=== DMG Created Successfully ==="
    echo "Path: $DMG_PATH"
    du -sh "$DMG_PATH" | awk '{print "Size: " $1}'
else
    echo "ERROR: DMG creation failed."
    exit 1
fi
