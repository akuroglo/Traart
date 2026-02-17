#!/bin/bash
# Traart Installer — copies app to /Applications and removes quarantine
# Usage: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_SRC="$PROJECT_DIR/build/Traart.app"
APP_DST="/Applications/Traart.app"

echo "=== Установка Traart ==="
echo ""

# Build if needed
if [ ! -d "$APP_SRC" ]; then
    echo "Приложение не собрано. Собираю..."
    bash "$SCRIPT_DIR/build.sh"
    echo ""
fi

# Remove old version
if [ -d "$APP_DST" ]; then
    echo "Удаляю предыдущую версию..."
    rm -rf "$APP_DST"
fi

# Copy
echo "Копирую в /Applications..."
cp -R "$APP_SRC" "$APP_DST"

# Remove quarantine
echo "Снимаю карантин Gatekeeper..."
xattr -cr "$APP_DST"

echo ""
echo "=== Установка завершена ==="
echo "Traart установлен в /Applications/Traart.app"
echo ""
echo "Запускаю..."
open "$APP_DST"
