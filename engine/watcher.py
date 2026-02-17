#!/usr/bin/env python3
"""File system watcher for monitoring new audio/video files.

Watches specified directories for new audio/video files and outputs
events as JSON lines to stdout for the Swift app to consume.

Usage:
    python watcher.py <folder1> [folder2] ... [--all-disk] [--extensions .m4a,.mp4,...]
"""

import argparse
import json
import os
import sys
import time
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Set

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileModifiedEvent

DEFAULT_EXTENSIONS = {
    ".wav", ".mp3", ".m4a", ".flac", ".ogg",
    ".mp4", ".mkv", ".webm", ".mov",
}

# Directories to skip when watching all-disk
SKIP_DIRS = {
    ".Trash",
    "Library/Caches",
    "Library/Logs",
    "Library/Saved Application State",
    "Library/WebKit",
    "Library/Containers",
    "Library/Developer",
    "Library/Group Containers",
    ".cache",
    ".npm",
    ".yarn",
    ".gradle",
    ".cargo",
    "node_modules",
    ".git",
    "__pycache__",
    ".venv",
    "venv",
}


def should_skip_path(path: str) -> bool:
    """Check if path is in a directory that should be skipped."""
    parts = Path(path).parts
    for skip in SKIP_DIRS:
        skip_parts = Path(skip).parts
        for i in range(len(parts) - len(skip_parts) + 1):
            if parts[i:i + len(skip_parts)] == skip_parts:
                return True
    return False


class AudioFileHandler(FileSystemEventHandler):
    """Handles filesystem events for audio/video files with debouncing."""

    def __init__(self, extensions: Set[str], debounce_seconds: float = 5.0):
        super().__init__()
        self.extensions = extensions
        self.debounce_seconds = debounce_seconds
        self._pending: Dict[str, float] = {}
        self._reported: Set[str] = set()
        self._lock = threading.Lock()
        self._timer_thread = threading.Thread(target=self._debounce_loop, daemon=True)
        self._timer_thread.start()

    def _is_audio_file(self, path: str) -> bool:
        """Check if file has a supported audio/video extension."""
        ext = Path(path).suffix.lower()
        return ext in self.extensions

    def on_created(self, event):
        if event.is_directory:
            return
        if self._is_audio_file(event.src_path) and not should_skip_path(event.src_path):
            self._schedule(event.src_path)

    def on_modified(self, event):
        if event.is_directory:
            return
        if self._is_audio_file(event.src_path) and not should_skip_path(event.src_path):
            self._schedule(event.src_path)

    def _schedule(self, path: str):
        """Schedule a file for reporting after debounce period."""
        with self._lock:
            self._pending[path] = time.monotonic()

    def _debounce_loop(self):
        """Background loop that checks for files ready to report."""
        while True:
            time.sleep(1.0)
            now = time.monotonic()
            ready = []

            with self._lock:
                for path, last_seen in list(self._pending.items()):
                    if (now - last_seen) >= self.debounce_seconds:
                        ready.append(path)
                        del self._pending[path]

            for path in ready:
                if path not in self._reported and os.path.exists(path):
                    self._reported.add(path)
                    self._emit_event(path)

    def _emit_event(self, path: str):
        """Output a new_file event as JSON line to stdout."""
        try:
            size = os.path.getsize(path)
        except OSError:
            size = 0

        event = {
            "event": "new_file",
            "path": os.path.abspath(path),
            "size": size,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
        }
        sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(description="Watch directories for new audio/video files")
    parser.add_argument("folders", nargs="*", help="Directories to watch")
    parser.add_argument(
        "--all-disk", action="store_true",
        help="Watch entire /Users/ directory tree (skips system dirs)",
    )
    parser.add_argument(
        "--extensions", type=str, default=None,
        help="Comma-separated list of extensions to watch (e.g. .m4a,.mp4)",
    )
    parser.add_argument(
        "--debounce", type=float, default=5.0,
        help="Seconds to wait after last modification before reporting (default: 5)",
    )
    args = parser.parse_args()

    if args.extensions:
        extensions = set()
        for ext in args.extensions.split(","):
            ext = ext.strip()
            if not ext.startswith("."):
                ext = "." + ext
            extensions.add(ext.lower())
    else:
        extensions = DEFAULT_EXTENSIONS

    folders = list(args.folders)
    if args.all_disk:
        users_dir = "/Users"
        if os.path.isdir(users_dir):
            folders.append(users_dir)
        else:
            home = os.path.expanduser("~")
            folders.append(home)

    if not folders:
        sys.stderr.write(json.dumps({"error": "No folders specified. Use positional args or --all-disk."}) + "\n")
        sys.stderr.flush()
        sys.exit(1)

    # Verify all folders exist
    for folder in folders:
        if not os.path.isdir(folder):
            sys.stderr.write(json.dumps({"error": f"Directory not found: {folder}"}) + "\n")
            sys.stderr.flush()
            sys.exit(1)

    handler = AudioFileHandler(extensions=extensions, debounce_seconds=args.debounce)
    observer = Observer()

    for folder in folders:
        observer.schedule(handler, folder, recursive=True)

    # Emit started event
    started = {
        "event": "started",
        "folders": [os.path.abspath(f) for f in folders],
        "extensions": sorted(extensions),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
    }
    sys.stdout.write(json.dumps(started, ensure_ascii=False) + "\n")
    sys.stdout.flush()

    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
