#!/usr/bin/env python3
"""First-launch environment setup for Traart.

Creates Python venv, installs dependencies, and downloads models.
Reports progress via stdout JSON lines for the Swift app.

Usage:
    python3 setup_env.py [--venv-path PATH] [--models-dir PATH] [--requirements PATH] [--python PATH]
"""

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

DEFAULT_APP_SUPPORT = os.path.expanduser("~/Library/Application Support/Traart")
DEFAULT_VENV_PATH = os.path.join(DEFAULT_APP_SUPPORT, "python-env")
DEFAULT_MODELS_DIR = os.path.join(DEFAULT_APP_SUPPORT, "models")
DEFAULT_REQUIREMENTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements.txt")

GIGAAM_MODEL_NAME = "v3_e2e_rnnt"

PYANNOTE_MODELS = [
    "pyannote/speaker-diarization-3.1",
    "pyannote/segmentation-3.0",
]


def report(step: str, progress: float, status: str):
    """Report progress as JSON line to stdout."""
    msg = {"step": step, "progress": round(progress, 2), "status": status}
    sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def report_error(message: str):
    """Report error as JSON line to stderr."""
    sys.stderr.write(json.dumps({"error": message}, ensure_ascii=False) + "\n")
    sys.stderr.flush()


def is_apple_silicon() -> bool:
    """Detect if running on Apple Silicon."""
    return platform.machine() == "arm64"


def find_python3(explicit_python: str = None) -> str:
    """Find a suitable Python 3 interpreter (3.10–3.13 for ML compatibility).

    Args:
        explicit_python: Path passed via --python flag (e.g. standalone Python).
    """
    # 1. Explicit --python flag from Swift (standalone or Homebrew)
    if explicit_python and os.path.isfile(explicit_python) and os.access(explicit_python, os.X_OK):
        return explicit_python

    # 2. Standalone Python in App Support
    standalone = os.path.expanduser(
        "~/Library/Application Support/Traart/python-standalone/bin/python3"
    )
    if os.path.isfile(standalone) and os.access(standalone, os.X_OK):
        return standalone

    # 3. Well-known Homebrew / system paths
    direct_paths = [
        "/opt/homebrew/bin/python3.13",
        "/opt/homebrew/bin/python3.12",
        "/opt/homebrew/bin/python3.11",
        "/opt/homebrew/bin/python3.10",
        "/usr/local/bin/python3.13",
        "/usr/local/bin/python3.12",
        "/usr/local/bin/python3.11",
        "/usr/local/bin/python3.10",
    ]
    for path in direct_paths:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path

    # 4. PATH-based lookup
    for candidate in ["python3.13", "python3.12", "python3.11", "python3.10"]:
        path = shutil.which(candidate)
        if path:
            return path

    # 5. Fallback: system python3 if it's >= 3.10
    path = shutil.which("python3")
    if path:
        result = subprocess.run([path, "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            ver = result.stdout.strip().split()[-1]
            major, minor = int(ver.split(".")[0]), int(ver.split(".")[1])
            if major == 3 and minor >= 10:
                return path
    return sys.executable


def _venv_python_version(venv_path: str):
    """Return (major, minor) of the Python inside an existing venv, or None."""
    venv_python = os.path.join(venv_path, "bin", "python3")
    if not os.path.isfile(venv_python):
        return None
    try:
        result = subprocess.run(
            [venv_python, "--version"], capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            ver = result.stdout.strip().split()[-1]
            parts = ver.split(".")
            return int(parts[0]), int(parts[1])
    except Exception:
        pass
    return None


def create_venv(venv_path: str, python_path: str = None):
    """Create a Python virtual environment."""
    report("creating_venv", 0.05, "Creating Python environment...")

    python = find_python3(python_path)
    if os.path.isdir(venv_path):
        pip_path = os.path.join(venv_path, "bin", "pip")
        if os.path.exists(pip_path):
            # Verify venv Python is >= 3.10; recreate if outdated
            ver = _venv_python_version(venv_path)
            if ver and ver[0] == 3 and ver[1] >= 10:
                report("creating_venv", 0.1, "Virtual environment already exists.")
                return
            report("creating_venv", 0.06,
                   f"Venv Python {ver[0]}.{ver[1]} outdated, recreating..." if ver
                   else "Recreating venv...")
        shutil.rmtree(venv_path)

    subprocess.run(
        [python, "-m", "venv", "--clear", venv_path],
        check=True,
        capture_output=True,
        text=True,
    )

    # Upgrade pip and pin setuptools (pkg_resources removed in setuptools>=81)
    pip_path = os.path.join(venv_path, "bin", "pip")
    subprocess.run(
        [pip_path, "install", "--upgrade", "pip", "setuptools<81"],
        check=True,
        capture_output=True,
        text=True,
    )

    report("creating_venv", 0.1, "Virtual environment created.")


def install_pytorch(venv_path: str):
    """Install PyTorch with appropriate backend for the platform."""
    report("installing_torch", 0.15, "Installing PyTorch...")

    pip_path = os.path.join(venv_path, "bin", "pip")

    # Check if already installed
    result = subprocess.run(
        [pip_path, "show", "torch"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        report("installing_torch", 0.3, "PyTorch already installed.")
        return

    if is_apple_silicon():
        # MPS backend is included in default PyTorch for macOS arm64
        subprocess.run(
            [pip_path, "install", "torch", "torchaudio"],
            check=True,
            capture_output=True,
            text=True,
            timeout=1800,
        )
    else:
        # Intel Mac - CPU only
        subprocess.run(
            [pip_path, "install", "torch", "torchaudio",
             "--index-url", "https://download.pytorch.org/whl/cpu"],
            check=True,
            capture_output=True,
            text=True,
            timeout=1800,
        )

    report("installing_torch", 0.3, "PyTorch installed.")


def install_requirements(venv_path: str, requirements_path: str):
    """Install all requirements from requirements.txt."""
    report("installing_deps", 0.35, "Installing dependencies...")

    pip_path = os.path.join(venv_path, "bin", "pip")

    # GigaAM's setup.py uses pkg_resources — needs --no-build-isolation
    # to use our pinned setuptools<81 instead of pip's isolated build env
    # Use zip URL instead of git+https to avoid git dependency
    subprocess.run(
        [pip_path, "install", "--no-build-isolation",
         "gigaam @ https://github.com/salute-developers/GigaAM/archive/refs/heads/main.zip"],
        check=True,
        capture_output=True,
        text=True,
        timeout=1800,
    )

    subprocess.run(
        [pip_path, "install", "-r", requirements_path],
        check=True,
        capture_output=True,
        text=True,
        timeout=1800,
    )

    report("installing_deps", 0.5, "Dependencies installed.")


def _sha256_file(path: str) -> str:
    """Compute SHA-256 hash of a file in chunks (memory-safe)."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def download_file(url: str, dest_path: str, expected_hash: str = None) -> bool:
    """Download a file with progress, verify SHA-256 if provided.

    Returns True if file was downloaded, False if it already existed.
    """
    if os.path.exists(dest_path):
        if expected_hash:
            actual = _sha256_file(dest_path)
            if actual == expected_hash:
                return False
            os.remove(dest_path)
        else:
            return False

    os.makedirs(os.path.dirname(dest_path), exist_ok=True)

    import tempfile
    fd, temp_path = tempfile.mkstemp(
        dir=os.path.dirname(dest_path), suffix=".download"
    )
    os.close(fd)
    try:
        with urllib.request.urlopen(url) as response, open(temp_path, "wb") as f:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                f.write(chunk)

        if expected_hash:
            actual = _sha256_file(temp_path)
            if actual != expected_hash:
                os.remove(temp_path)
                raise RuntimeError(f"SHA-256 mismatch for {url}: expected {expected_hash}, got {actual}")

        os.rename(temp_path, dest_path)
        return True

    except Exception:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise


GIGAAM_CDN_URL = "https://cdn.chatwm.opensmodel.sberdevices.ru/GigaAM"
GIGAAM_FILES = {
    f"{GIGAAM_MODEL_NAME}.ckpt": "2730de7545ac43ad256485a462b0a27a",
    f"{GIGAAM_MODEL_NAME}_tokenizer.model": None,  # no hash check for tokenizer
}


def _md5_file(path: str) -> str:
    """Compute MD5 hash of a file (matches gigaam's hash_path)."""
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _curl_download(url: str, dest: str, max_retries: int = 10) -> bool:
    """Download a file using curl with resume support.

    Returns True on success. Retries with resume on failure.
    Uses --speed-limit to detect stalled connections and --retry for
    transient HTTP errors. curl -C - resumes partial downloads.
    """
    curl = shutil.which("curl") or "/usr/bin/curl"
    for attempt in range(1, max_retries + 1):
        result = subprocess.run(
            [
                curl, "-fSL",
                "-C", "-",                # resume partial downloads
                "--connect-timeout", "30", # fail fast on DNS/connect issues
                "--speed-limit", "10000",  # abort if < 10 KB/s ...
                "--speed-time", "30",      # ... for 30 seconds
                "--retry", "3",            # curl-level retry for HTTP errors
                "--retry-delay", "5",
                "-o", dest, url,
            ],
            capture_output=True,
            text=True,
            timeout=3600,  # 1 hour hard limit
        )
        if result.returncode == 0:
            return True
        if attempt < max_retries:
            import time
            delay = min(5 * attempt, 30)
            report("downloading_gigaam", 0.55 + 0.015 * attempt,
                   f"Ошибка загрузки, попытка {attempt + 1}/{max_retries} (через {delay}с)...")
            time.sleep(delay)
    return False


def download_gigaam_models(models_dir: str, venv_path: str):
    """Pre-download GigaAM v3 model checkpoint and tokenizer via curl."""
    report("downloading_gigaam", 0.55, "Downloading GigaAM model...")

    gigaam_dir = os.path.join(models_dir, "gigaam")
    os.makedirs(gigaam_dir, exist_ok=True)

    for filename, expected_md5 in GIGAAM_FILES.items():
        dest = os.path.join(gigaam_dir, filename)
        url = f"{GIGAAM_CDN_URL}/{filename}"

        # Skip if file exists and hash matches
        if os.path.exists(dest):
            if expected_md5 is None or _md5_file(dest) == expected_md5:
                continue
            # Hash mismatch — corrupt/partial file, will resume via curl
            report("downloading_gigaam", 0.56, f"Повторная загрузка {filename}...")

        if not _curl_download(url, dest):
            report_error(f"Failed to download {filename} after retries")
            raise RuntimeError(f"GigaAM download failed: {filename}")

        if expected_md5:
            actual = _md5_file(dest)
            if actual != expected_md5:
                os.remove(dest)
                report_error(f"MD5 mismatch for {filename}: expected {expected_md5}, got {actual}")
                raise RuntimeError(f"GigaAM checksum failed for {filename}")

    report("downloading_gigaam", 0.7, "GigaAM model downloaded.")


def download_pyannote_models(models_dir: str, venv_path: str):
    """Download pyannote models using huggingface_hub within the venv.

    This requires HF_TOKEN to be set for the initial download.
    After download, models are cached locally and no token is needed.
    """
    report("downloading_pyannote", 0.75, "Downloading pyannote models...")

    pyannote_dir = os.path.join(models_dir, "pyannote")
    os.makedirs(pyannote_dir, exist_ok=True)

    python_path = os.path.join(venv_path, "bin", "python")

    # Download using huggingface_hub snapshot_download within the venv
    # Download script that receives parameters via sys.argv, not f-strings
    download_script = """
import os, sys
try:
    from huggingface_hub import snapshot_download
    repo_id = sys.argv[1]
    local_dir = sys.argv[2]
    token = os.environ.get("HF_TOKEN")
    if not token:
        print(f"HF_TOKEN not set, skipping {repo_id} download", file=sys.stderr)
        sys.exit(0)
    path = snapshot_download(repo_id=repo_id, token=token, local_dir=local_dir)
    print(f"Downloaded to {path}")
except Exception as e:
    print(f"Warning: could not download {sys.argv[1]}: {e}", file=sys.stderr)
    sys.exit(0)
"""
    # Minimal environment — only what's needed
    safe_env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", ""),
        "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
        "HF_TOKEN": os.environ.get("HF_TOKEN", ""),
    }

    for model_id in PYANNOTE_MODELS:
        model_name = model_id.split("/")[-1]
        target_dir = os.path.join(pyannote_dir, model_name)

        if os.path.isdir(target_dir) and any(os.scandir(target_dir)):
            continue

        subprocess.run(
            [python_path, "-c", download_script, model_id, target_dir],
            capture_output=True,
            text=True,
            timeout=1800,
            env=safe_env,
        )

    report("downloading_pyannote", 0.9, "Pyannote models downloaded.")


def verify_installation(venv_path: str):
    """Verify that all key modules can be imported."""
    report("verifying", 0.92, "Verifying installation...")

    python_path = os.path.join(venv_path, "bin", "python")

    checks = [
        "import torch; print(f'torch {torch.__version__}')",
        "import torchaudio; print(f'torchaudio {torchaudio.__version__}')",
        "import gigaam; print('gigaam OK')",
        "import watchdog; print('watchdog OK')",
    ]

    all_ok = True
    for check in checks:
        try:
            result = subprocess.run(
                [python_path, "-c", check],
                capture_output=True,
                text=True,
                timeout=120,
            )
            if result.returncode != 0:
                report_error(f"Verification failed: {check} -> {result.stderr.strip()}")
                all_ok = False
        except subprocess.TimeoutExpired:
            report_error(f"Verification timed out: {check}")
            all_ok = False

    # Check pyannote separately (it may not be installed if HF_TOKEN was missing)
    try:
        result = subprocess.run(
            [python_path, "-c", "from pyannote.audio import Pipeline; print('pyannote OK')"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            report_error("pyannote.audio not available. Diarization will be disabled.")
    except subprocess.TimeoutExpired:
        report_error("pyannote.audio import timed out. Diarization will be disabled.")

    # Check MPS availability
    try:
        result = subprocess.run(
            [python_path, "-c",
             "import torch; print('MPS' if torch.backends.mps.is_available() else 'CPU')"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        device = result.stdout.strip() if result.returncode == 0 else "CPU"
    except subprocess.TimeoutExpired:
        device = "CPU"

    if all_ok:
        report("verifying", 0.95, f"Verification passed. Device: {device}")
    else:
        report("verifying", 0.95, "Verification completed with warnings.")


def main():
    parser = argparse.ArgumentParser(description="Traart environment setup")
    parser.add_argument(
        "--venv-path", type=str, default=DEFAULT_VENV_PATH,
        help=f"Path for Python venv (default: {DEFAULT_VENV_PATH})",
    )
    parser.add_argument(
        "--models-dir", type=str, default=DEFAULT_MODELS_DIR,
        help=f"Path for model downloads (default: {DEFAULT_MODELS_DIR})",
    )
    parser.add_argument(
        "--requirements", type=str, default=DEFAULT_REQUIREMENTS,
        help="Path to requirements.txt",
    )
    parser.add_argument(
        "--skip-models", action="store_true",
        help="Skip model downloads (only setup venv and deps)",
    )
    parser.add_argument(
        "--python", type=str, default=None,
        help="Path to Python interpreter for venv creation (e.g. standalone Python)",
    )
    args = parser.parse_args()

    try:
        report("starting", 0.0, "Starting Traart environment setup...")

        create_venv(args.venv_path, args.python)
        install_pytorch(args.venv_path)
        install_requirements(args.venv_path, args.requirements)

        if not args.skip_models:
            download_gigaam_models(args.models_dir, args.venv_path)
            download_pyannote_models(args.models_dir, args.venv_path)

        verify_installation(args.venv_path)

        report("complete", 1.0, "Setup complete!")

    except subprocess.CalledProcessError as e:
        report_error(f"Command failed: {e.cmd}\nstderr: {e.stderr}")
        sys.exit(1)
    except Exception as e:
        report_error(str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
