#!/bin/bash
# Build the TraartApp Swift package and create .app bundle
# Usage: ./scripts/build.sh
# Set CHANNEL env var for distribution: CHANNEL=website ./scripts/build.sh
# Valid channels: github (default), website, homebrew

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

# Distribution channel: github, website, homebrew (default: github)
CHANNEL="${CHANNEL:-github}"
CHANNEL_FLAG="CHANNEL_$(echo "$CHANNEL" | tr '[:lower:]' '[:upper:]')"
SWIFT_DEFINES="-Xswiftc -D${CHANNEL_FLAG}"
echo "Distribution channel: $CHANNEL (flag: $CHANNEL_FLAG)"
APP_BUNDLE="$BUILD_DIR/Traart.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENGINE_DIR="$RESOURCES_DIR/engine"

echo "=== Traart Build Script ==="
echo "Project directory: $PROJECT_DIR"

# Clean previous build
if [ -d "$APP_BUNDLE" ]; then
    echo "Cleaning previous build..."
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$BUILD_DIR"

# Step 1: Build Universal Binary (arm64 + x86_64)
echo ""
echo "[1/5] Building Universal Binary..."
cd "$PROJECT_DIR/TraartApp"

swift build -c release --arch arm64 $SWIFT_DEFINES 2>&1
ARM64_BIN=$(swift build -c release --arch arm64 $SWIFT_DEFINES --show-bin-path)/TraartApp

swift build -c release --arch x86_64 $SWIFT_DEFINES 2>&1
X86_BIN=$(swift build -c release --arch x86_64 $SWIFT_DEFINES --show-bin-path)/TraartApp

if [ ! -f "$ARM64_BIN" ] || [ ! -f "$X86_BIN" ]; then
    echo "ERROR: One or both architecture builds failed"
    exit 1
fi

BINARY_PATH="$BUILD_DIR/TraartApp-universal"
lipo -create "$ARM64_BIN" "$X86_BIN" -output "$BINARY_PATH"
echo "Universal binary created: $(lipo -info "$BINARY_PATH")"

# Step 2: Create .app bundle structure
echo ""
echo "[2/5] Creating .app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$ENGINE_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/TraartApp"
chmod +x "$MACOS_DIR/TraartApp"

# Step 3: Generate Info.plist
echo ""
echo "[3/5] Generating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Traart</string>
    <key>CFBundleDisplayName</key>
    <string>Traart</string>
    <key>CFBundleIdentifier</key>
    <string>com.traart.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>TraartApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Traart использует микрофон для записи голосовых заметок и последующей транскрибации в текст.</string>
</dict>
</plist>
PLIST

# Step 4: Generate and copy app icon
echo ""
echo "[4/5] Generating app icon..."
ICON_PATH="$BUILD_DIR/AppIcon.icns"
if [ ! -f "$ICON_PATH" ]; then
    swift "$SCRIPT_DIR/generate-icon.swift" 2>&1
fi
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
    echo "  Copied: AppIcon.icns"
else
    echo "  WARNING: AppIcon.icns not found, using default icon"
fi

# Step 5: Copy Python engine files
echo ""
echo "[5/5] Copying engine files..."
ENGINE_SRC="$PROJECT_DIR/engine"
ENGINE_FILES=(
    "transcribe.py"
    "diarize.py"
    "watcher.py"
    "setup_env.py"
    "requirements.txt"
)

for file in "${ENGINE_FILES[@]}"; do
    if [ -f "$ENGINE_SRC/$file" ]; then
        cp "$ENGINE_SRC/$file" "$ENGINE_DIR/$file"
        echo "  Copied: $file"
    else
        echo "  WARNING: $file not found in engine/"
    fi
done

# Code signing
# Use Developer ID if available, otherwise ad-hoc
echo ""
DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')

if [ -n "$DEVELOPER_ID" ]; then
    echo "Code signing with Developer ID: $DEVELOPER_ID"
    codesign --force --options runtime --sign "$DEVELOPER_ID" "$APP_BUNDLE" 2>&1
    echo "Signed with Developer ID (hardened runtime enabled)"

    # Notarization
    echo ""
    echo "Notarizing..."
    APPLE_ID="${APPLE_ID:-}"
    TEAM_ID="${TEAM_ID:-}"
    NOTARY_PROFILE="${NOTARY_PROFILE:-traart-notary}"

    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        # Create zip for notarization
        NOTARIZE_ZIP="$BUILD_DIR/Traart-notarize.zip"
        ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

        xcrun notarytool submit "$NOTARIZE_ZIP" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait 2>&1

        # Staple the ticket
        xcrun stapler staple "$APP_BUNDLE" 2>&1
        rm -f "$NOTARIZE_ZIP"
        echo "Notarization complete, ticket stapled"
    elif [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ]; then
        echo "No keychain profile found. Set up with:"
        echo "  xcrun notarytool store-credentials traart-notary --apple-id $APPLE_ID --team-id $TEAM_ID"
        echo "Skipping notarization."
    else
        echo "Skipping notarization (set APPLE_ID, TEAM_ID, or run: xcrun notarytool store-credentials traart-notary)"
    fi
else
    echo "Code signing (ad-hoc — no Developer ID found)..."
    codesign --force --sign - "$APP_BUNDLE" 2>&1 || {
        echo "WARNING: Code signing failed (may require Xcode tools). App bundle is still usable locally."
    }
    echo ""
    echo "To sign with Developer ID:"
    echo "  1. Open Xcode → Settings → Accounts → Manage Certificates"
    echo "  2. Create 'Developer ID Application' certificate"
    echo "  3. Re-run this script"
fi

# Verify
echo ""
echo "=== Build Complete ==="
echo "App bundle: $APP_BUNDLE"
echo ""
echo "Bundle structure:"
find "$APP_BUNDLE" -type f | sort | while read -r f; do
    echo "  ${f#$APP_BUNDLE/}"
done
echo ""
du -sh "$APP_BUNDLE" | awk '{print "Bundle size: " $1}'
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "Authority|Signature|TeamIdentifier" || true
