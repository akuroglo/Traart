#!/bin/bash
# Create a .pkg installer that installs Traart without Gatekeeper warnings.
# The pkg postinstall script removes quarantine attributes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Traart.app"
PKG_OUTPUT="$BUILD_DIR/Traart-Installer.pkg"

echo "=== Traart PKG Installer Builder ==="

# Build app if needed
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Building app first..."
    bash "$SCRIPT_DIR/build.sh"
fi

# Create staging area
STAGING_DIR=$(mktemp -d)
SCRIPTS_DIR=$(mktemp -d)
trap "rm -rf '$STAGING_DIR' '$SCRIPTS_DIR'" EXIT

# Stage the app
mkdir -p "$STAGING_DIR/Applications"
cp -R "$APP_BUNDLE" "$STAGING_DIR/Applications/Traart.app"

# Create postinstall script that removes quarantine
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/bash
# Remove quarantine attribute so Gatekeeper doesn't block the app
xattr -cr /Applications/Traart.app 2>/dev/null || true
exit 0
POSTINSTALL
chmod +x "$SCRIPTS_DIR/postinstall"

# Remove old pkg
rm -f "$PKG_OUTPUT"

# Build the pkg
echo "Creating installer package..."
pkgbuild \
    --root "$STAGING_DIR" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.traart.app" \
    --version "1.0.0" \
    --install-location "/" \
    "$PKG_OUTPUT"

echo ""
echo "=== PKG Created ==="
echo "Path: $PKG_OUTPUT"
ls -lh "$PKG_OUTPUT" | awk '{print "Size: " $5}'
