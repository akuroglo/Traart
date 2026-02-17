#!/bin/bash
# Set up Python virtual environment for Traart development
# Usage: ./scripts/setup-python-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENGINE_DIR="$PROJECT_DIR/engine"
VENV_DIR="$ENGINE_DIR/.venv"
REQUIREMENTS="$ENGINE_DIR/requirements.txt"

echo "=== Traart Python Environment Setup ==="

# Check Python 3 availability
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found. Please install Python 3.10+ first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1)
echo "Using: $PYTHON_VERSION"

# Check requirements.txt exists
if [ ! -f "$REQUIREMENTS" ]; then
    echo "ERROR: requirements.txt not found at $REQUIREMENTS"
    exit 1
fi

# Create virtual environment
if [ -d "$VENV_DIR" ]; then
    echo "Existing venv found. Removing..."
    rm -rf "$VENV_DIR"
fi

echo ""
echo "[1/3] Creating virtual environment..."
python3 -m venv "$VENV_DIR"

# Activate and install
echo ""
echo "[2/3] Installing dependencies..."
source "$VENV_DIR/bin/activate"

pip install --upgrade pip setuptools wheel 2>&1 | tail -1
pip install -r "$REQUIREMENTS" 2>&1

# Verify key imports
echo ""
echo "[3/3] Verifying imports..."
FAILED=0

verify_import() {
    local module="$1"
    local display_name="${2:-$module}"
    if python3 -c "import $module" 2>/dev/null; then
        echo "  [OK] $display_name"
    else
        echo "  [FAIL] $display_name"
        FAILED=1
    fi
}

verify_import "torch" "torch (PyTorch)"
verify_import "torchaudio" "torchaudio"
verify_import "gigaam" "gigaam"
verify_import "pyannote.audio" "pyannote.audio"
verify_import "watchdog" "watchdog"
verify_import "huggingface_hub" "huggingface_hub"

deactivate

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "=== Setup Complete ==="
    echo "Virtual environment: $VENV_DIR"
    echo "Activate with: source $VENV_DIR/bin/activate"
else
    echo "=== Setup Completed With Errors ==="
    echo "Some imports failed. Check the output above."
    exit 1
fi
