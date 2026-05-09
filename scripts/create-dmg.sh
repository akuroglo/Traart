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

# Verify DMG was created
if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG creation failed."
    exit 1
fi

# Sign + notarize + staple the DMG itself.
# Without this, Safari's quarantine bit triggers an "Apple could not verify"
# warning on the DMG even though the .app inside is already notarized.
DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" | head -1 \
    | sed 's/.*"\(.*\)".*/\1/')

if [ -n "$DEVELOPER_ID" ]; then
    echo ""
    echo "Signing DMG with Developer ID..."
    codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH" 2>&1

    NOTARY_PROFILE="${NOTARY_PROFILE:-traart-notary}"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "Notarizing DMG (5–15 min)..."
        xcrun notarytool submit "$DMG_PATH" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait 2>&1

        echo "Stapling notarization ticket to DMG..."
        xcrun stapler staple "$DMG_PATH" 2>&1
        echo "DMG notarized + stapled"
    else
        echo "WARNING: notary profile '$NOTARY_PROFILE' not found — DMG signed but NOT notarized."
        echo "Set up with: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id … --team-id …"
    fi
else
    echo "WARNING: no Developer ID Application cert in keychain — DMG left unsigned."
fi

echo ""
echo "=== DMG Created Successfully ==="
echo "Path: $DMG_PATH"
du -sh "$DMG_PATH" | awk '{print "Size: " $1}'
