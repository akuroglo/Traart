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
    """Install PyTorch with appropriate backend for the platform.

    Pinned to 2.7.* — torchaudio 2.8 dropped its built-in audio backends and
    delegates decoding to torchcodec, which requires system FFmpeg dylibs we
    do not ship. pyannote.audio 3.3.2 then crashes with
    "TorchCodec is required for load_with_torchcodec".
    """
    report("installing_torch", 0.15, "Installing PyTorch...")

    pip_path = os.path.join(venv_path, "bin", "pip")
    torch_spec = "torch==2.7.*"
    torchaudio_spec = "torchaudio==2.7.*"

    # Check installed version; force-reinstall if outside 2.7.x range
    result = subprocess.run(
        [pip_path, "show", "torch"],
        capture_output=True, text=True,
    )
    needs_install = True
    if result.returncode == 0:
        version_line = next(
            (line for line in result.stdout.splitlines() if line.startswith("Version:")),
            "",
        )
        installed = version_line.split(":", 1)[1].strip() if ":" in version_line else ""
        if installed.startswith("2.7."):
            report("installing_torch", 0.3, f"PyTorch {installed} already installed.")
            return
        report("installing_torch", 0.18,
               f"Replacing PyTorch {installed} with 2.7.* (compatibility)...")

    install_args = [pip_path, "install", "--upgrade", torch_spec, torchaudio_spec]
    if not is_apple_silicon():
        install_args += ["--index-url", "https://download.pytorch.org/whl/cpu"]

    subprocess.run(
        install_args,
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
    # to use our pinned setuptools<81 instead of pip's isolated build env.
    # Pinned to commit 6e4b027c (2026-04-15) — main moved transcribe() from
    # str to TranscriptionResult; future API drift would break us silently.
    GIGAAM_COMMIT = "6e4b027c6fb554e09e8b9059b757a175295ab879"
    subprocess.run(
        [pip_path, "install", "--no-build-isolation",
         f"gigaam @ https://github.com/salute-developers/GigaAM/archive/{GIGAAM_COMMIT}.zip"],
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
# Immutable release assets, mirrored from the original GigaAM files. Keep the
# upstream CDN as a fallback, with TLS verification enabled for both sources.
GIGAAM_DOWNLOAD_URLS = (
    "https://github.com/akuroglo/Traart/releases/download/models-gigaam-v3-f60c62fe",
    GIGAAM_CDN_URL,
)
# SHA-256 pins cover both weights and tokenizer (including existing caches).
GIGAAM_FILES = {
    f"{GIGAAM_MODEL_NAME}.ckpt": "f60c62fe45902d967000770a12f260de7c5ac4d4b8e5e852f1df8c548e3958b5",
    f"{GIGAAM_MODEL_NAME}_tokenizer.model": "828c12c991019eef952a960661f25a92d6ad279591e2ea466b4aeddf1d20a18a",
}


def _curl_download(url: str, dest: str, max_retries: int = 3) -> bool:
    """Resume transient failures; fail fast on certificate/permanent HTTP errors."""
    curl = shutil.which("curl") or "/usr/bin/curl"
    for attempt in range(1, max_retries + 1):
        try:
            result = subprocess.run(
                [
                    curl, "-fsSL",
                    "-C", "-",
                    "--connect-timeout", "30",
                    "--speed-limit", "10000",
                    "--speed-time", "30",
                    "--write-out", "%{http_code}",
                    "-o", dest, url,
                ],
                capture_output=True,
                text=True,
                timeout=3600,
            )
        except subprocess.TimeoutExpired:
            report_error(f"Download timed out after 3600s: {url}")
            return False
        if result.returncode == 0:
            return True

        http_status = result.stdout.strip()
        report_error(
            f"Download failed: {url} (curl exit {result.returncode}, "
            f"HTTP {http_status or 'unknown'}): {result.stderr.strip()}"
        )
        # Retrying the same expired certificate cannot help. Preserve the
        # actual curl error in setup.log and let the caller try the next host.
        if result.returncode in (51, 58, 60, 77, 83):
            return False
        if result.returncode == 33 or http_status == "416":
            # This server cannot resume, or the partial file is oversized.
            if os.path.exists(dest):
                os.remove(dest)
            continue
        if http_status.startswith("4") and http_status not in ("408", "429"):
            return False
        if attempt < max_retries:
            import time
            delay = 5 * attempt
            report("downloading_gigaam", 0.55 + 0.015 * attempt,
                   f"Ошибка загрузки, попытка {attempt + 1}/{max_retries} (через {delay}с)...")
            time.sleep(delay)
    return False


def download_gigaam_models(models_dir: str, venv_path: str):
    """Download verified GigaAM files, with a mirror and atomic cache updates."""
    report("downloading_gigaam", 0.55, "Downloading GigaAM model...")

    gigaam_dir = os.path.join(models_dir, "gigaam")
    os.makedirs(gigaam_dir, exist_ok=True)

    for filename, expected_sha256 in GIGAAM_FILES.items():
        dest = os.path.join(gigaam_dir, filename)

        if os.path.exists(dest):
            if _sha256_file(dest) == expected_sha256:
                continue
            # A corrupt cache is not a resumable prefix, especially for the
            # tokenizer (older installers accepted even empty tokenizer files).
            os.remove(dest)
            report("downloading_gigaam", 0.56, f"Повторная загрузка {filename}...")

        for source_index, base_url in enumerate(GIGAAM_DOWNLOAD_URLS):
            url = f"{base_url}/{filename}"
            # Never concatenate partial data from different sources. Keep a
            # stable name so an interrupted setup can resume on the next run.
            partial = f"{dest}.{source_index}.download"
            report("downloading_gigaam", 0.56,
                   f"Загрузка {filename}: источник {source_index + 1}/{len(GIGAAM_DOWNLOAD_URLS)}")
            resuming = os.path.exists(partial) and os.path.getsize(partial) > 0
            for fresh_attempt in range(2 if resuming else 1):
                if not _curl_download(url, partial):
                    break
                actual = _sha256_file(partial)
                if actual == expected_sha256:
                    os.replace(partial, dest)
                    break
                report_error(
                    f"SHA-256 mismatch for {url}: expected {expected_sha256}, got {actual}"
                )
                os.remove(partial)
                # A stale partial file may be corrupt; retry from scratch once.
            if os.path.exists(dest):
                break
            if os.path.exists(partial):
                os.remove(partial)
        else:
            message = (
                f"Не удалось скачать {filename} ни из одного источника. "
                "Подробная причина записана в setup.log."
            )
            report_error(message)
            raise RuntimeError(message)

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
