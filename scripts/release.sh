#!/bin/bash
# Create a signed release and update appcast.xml for Sparkle auto-updates.
#
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.1.0
#
# Prerequisites:
#   - Run ./scripts/generate-keys.sh first (once)
#   - sparkle_ed25519.key must exist in project root
#
# This script:
#   1. Builds the app
#   2. Creates Traart-<version>.zip
#   3. Signs with EdDSA
#   4. Updates appcast.xml
#   5. Creates a GitHub release (if gh CLI is available)

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.1.0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Traart.app"
RELEASE_ZIP="$BUILD_DIR/Traart-${VERSION}.zip"
PRIV_KEY="$PROJECT_DIR/sparkle_ed25519.key"
APPCAST="$PROJECT_DIR/appcast.xml"
GITHUB_REPO="akuroglo/Traart"

echo "=== Traart Release v${VERSION} ==="

# Check signing key
if [ ! -f "$PRIV_KEY" ]; then
    echo "ERROR: Signing key not found at $PRIV_KEY"
    echo "Run ./scripts/generate-keys.sh first."
    exit 1
fi

# Step 1: Update version in build script
echo ""
echo "[1/5] Updating version to ${VERSION}..."
sed -i '' "s|<string>[0-9]*\.[0-9]*\.[0-9]*</string><!-- CFBundleVersion -->|<string>${VERSION}</string><!-- CFBundleVersion -->|" "$SCRIPT_DIR/build.sh" 2>/dev/null || true
# Also update directly in the template
sed -i '' "s|<key>CFBundleVersion</key>|<key>CFBundleVersion</key>|" "$SCRIPT_DIR/build.sh"

# Step 2: Build
echo ""
echo "[2/5] Building..."
bash "$SCRIPT_DIR/build.sh"

# Patch version into the built Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist"

# Re-sign after plist modification
codesign --force --sign - "$APP_BUNDLE" 2>&1 || true

# Step 3: Create ZIP
echo ""
echo "[3/5] Creating release archive..."
rm -f "$RELEASE_ZIP"
cd "$BUILD_DIR"
ditto -c -k --keepParent "Traart.app" "Traart-${VERSION}.zip"
cd "$PROJECT_DIR"
ZIP_SIZE=$(stat -f%z "$RELEASE_ZIP")
echo "  Archive: $RELEASE_ZIP ($ZIP_SIZE bytes)"

# Step 4: Sign with EdDSA
echo ""
echo "[4/5] Signing archive..."

# Try Sparkle's sign_update tool first
SIGN_TOOL=$(find "$PROJECT_DIR/TraartApp/.build" -name "sign_update" -type f 2>/dev/null | head -1)

if [ -n "$SIGN_TOOL" ] && [ -x "$SIGN_TOOL" ]; then
    SIGNATURE=$("$SIGN_TOOL" "$RELEASE_ZIP" --ed-key-file "$PRIV_KEY" 2>&1 | grep "sparkle:edSignature" | sed 's/.*"\(.*\)".*/\1/' || echo "")
else
    # Fallback: manual EdDSA signing with openssl
    SIGNATURE=$(cat "$RELEASE_ZIP" | openssl dgst -sign "$PRIV_KEY" -binary 2>/dev/null | base64 || echo "SIGN_MANUALLY")
fi

if [ -z "$SIGNATURE" ] || [ "$SIGNATURE" = "SIGN_MANUALLY" ]; then
    echo "  WARNING: Could not auto-sign. You'll need to sign manually."
    SIGNATURE="REPLACE_WITH_SIGNATURE"
fi
echo "  Signature: ${SIGNATURE:0:20}..."

# Step 5: Update appcast.xml
echo ""
echo "[5/5] Updating appcast.xml..."
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/Traart-${VERSION}.zip"
PUB_DATE=$(date -u '+%a, %d %b %Y %H:%M:%S %z')

cat > "$APPCAST" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Traart Updates</title>
    <description>Обновления Traart</description>
    <language>ru</language>
    <item>
      <title>Traart ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL}"
        length="${ZIP_SIZE}"
        type="application/octet-stream"
        sparkle:edSignature="${SIGNATURE}"
      />
    </item>
  </channel>
</rss>
APPCAST_EOF

echo "  Updated: $APPCAST"

# Create GitHub release if gh CLI is available
echo ""
if command -v gh &>/dev/null; then
    echo "Creating GitHub release v${VERSION}..."
    gh release create "v${VERSION}" \
        "$RELEASE_ZIP" \
        --repo "$GITHUB_REPO" \
        --title "Traart v${VERSION}" \
        --notes "Traart v${VERSION}" \
        --draft \
        2>&1 || echo "WARNING: GitHub release creation failed. Create manually."
    echo ""
    echo "NOTE: Release created as DRAFT. Review and publish on GitHub."
else
    echo "gh CLI not found. Create release manually:"
    echo "  1. Go to https://github.com/${GITHUB_REPO}/releases/new"
    echo "  2. Tag: v${VERSION}"
    echo "  3. Upload: $RELEASE_ZIP"
fi

echo ""
echo "=== Release v${VERSION} Ready ==="
echo ""
echo "Next steps:"
echo "  1. Commit appcast.xml to main branch"
echo "  2. Publish the GitHub release (if draft)"
echo "  3. Users will receive update automatically within 24h"
echo ""
echo "Files:"
echo "  Archive:  $RELEASE_ZIP"
echo "  Appcast:  $APPCAST"
