#!/bin/bash
# Build the TraartApp Swift package and create .app bundle
# Usage: ./scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
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

swift build -c release --arch arm64 2>&1
ARM64_BIN=$(swift build -c release --arch arm64 --show-bin-path)/TraartApp

swift build -c release --arch x86_64 2>&1
X86_BIN=$(swift build -c release --arch x86_64 --show-bin-path)/TraartApp

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

# Ad-hoc code sign
echo ""
echo "Code signing..."
codesign --force --sign - "$APP_BUNDLE" 2>&1 || {
    echo "WARNING: Code signing failed (may require Xcode tools). App bundle is still usable locally."
}

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
