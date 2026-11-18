"""Exercise downloader recovery with real curl and a local HTTP server.

Run: python3 -m unittest discover -s engine/tests -v
No model downloads, ML dependencies, or changes to the user's cache.
"""

import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "setup_env", Path(__file__).resolve().parents[1] / "setup_env.py"
)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class DownloadTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cache = self.root / "gigaam"
        self.cache.mkdir()
        self.weights = "v3_e2e_rnnt.ckpt"
        self.tokenizer = "v3_e2e_rnnt_tokenizer.model"
        self.payloads = {self.weights: b"verified model weights", self.tokenizer: b"verified tokenizer"}
        self.routes = {}
        self.requests = []
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                offset = self.headers.get("Range")
                owner.requests.append((self.path, offset))
                status, body, ranges = owner.routes.get(self.path, (404, b"missing", False))
                if status == 200 and ranges and offset:
                    start = int(offset.removeprefix("bytes=").split("-")[0])
                    if start >= len(body):
                        self.send_response(416)
                        self.end_headers()
                        return
                    self.send_response(206)
                    self.send_header("Content-Range", f"bytes {start}-{len(body)-1}/{len(body)}")
                    body = body[start:]
                else:
                    self.send_response(status)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_server)
        base = f"http://127.0.0.1:{self.server.server_port}"
        self.sources = (base + "/primary", base + "/backup")
        for source in ("primary", "backup"):
            for name, data in self.payloads.items():
                self.routes[f"/{source}/{name}"] = (200, data, True)
        patches = (
            patch.object(setup, "GIGAAM_DOWNLOAD_URLS", self.sources),
            patch.object(setup, "GIGAAM_FILES", {
                name: hashlib.sha256(data).hexdigest() for name, data in self.payloads.items()
            }),
            patch.dict(os.environ, {"NO_PROXY": "127.0.0.1", "no_proxy": "127.0.0.1"}),
        )
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.logs = io.StringIO()

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def download(self):
        with contextlib.redirect_stdout(self.logs), contextlib.redirect_stderr(self.logs):
            setup.download_gigaam_models(str(self.root), "unused")

    def assert_valid_cache(self):
        for name, data in self.payloads.items():
            self.assertEqual((self.cache / name).read_bytes(), data)
        self.assertEqual(list(self.cache.glob("*.download")), [])

    def test_downloads_both_files_and_reuses_verified_cache(self):
        self.download()
        self.assert_valid_cache()
        self.requests.clear()
        self.download()
        self.assertEqual(self.requests, [])

    def test_missing_primary_uses_backup_without_sleeping(self):
        self.routes[f"/primary/{self.weights}"] = (404, b"missing", False)
        with patch("time.sleep") as sleep:
            self.download()
        sleep.assert_not_called()
        self.assert_valid_cache()
        self.assertIn((f"/backup/{self.weights}", None), self.requests)
        self.assertIn("HTTP 404", self.logs.getvalue())

    def test_wrong_checksum_switches_source(self):
        self.routes[f"/primary/{self.weights}"] = (200, b"corrupt", True)
        self.download()
        self.assert_valid_cache()
        self.assertIn("SHA-256 mismatch", self.logs.getvalue())

    def test_no_unverified_model_is_installed_if_all_sources_fail(self):
        for source in ("primary", "backup"):
            self.routes[f"/{source}/{self.weights}"] = (200, b"corrupt", True)
        with self.assertRaisesRegex(RuntimeError, "ни из одного источника"):
            self.download()
        self.assertFalse((self.cache / self.weights).exists())
        self.assertEqual(list(self.cache.glob("*.download")), [])

    def test_repairs_empty_tokenizer_from_old_installer(self):
        (self.cache / self.weights).write_bytes(self.payloads[self.weights])
        (self.cache / self.tokenizer).write_bytes(b"")
        self.download()
        self.assert_valid_cache()
        self.assertEqual(self.requests, [(f"/primary/{self.tokenizer}", None)])

    def test_replaces_corrupt_legacy_checkpoint_from_scratch(self):
        (self.cache / self.weights).write_bytes(b"corrupt legacy partial")
        self.download()
        self.assert_valid_cache()
        self.assertEqual(self.requests[0], (f"/primary/{self.weights}", None))

    def test_resumes_interrupted_download(self):
        (self.cache / f"{self.weights}.0.download").write_bytes(self.payloads[self.weights][:5])
        self.download()
        self.assert_valid_cache()
        self.assertEqual(self.requests[0], (f"/primary/{self.weights}", "bytes=5-"))

    def test_corrupt_partial_restarts_on_same_source(self):
        (self.cache / f"{self.weights}.0.download").write_bytes(b"wrong")
        self.download()
        self.assert_valid_cache()
        self.assertEqual(self.requests[:2], [
            (f"/primary/{self.weights}", "bytes=5-"), (f"/primary/{self.weights}", None),
        ])

    def test_server_without_range_support_restarts_download(self):
        (self.cache / f"{self.weights}.0.download").write_bytes(b"prefix")
        self.routes[f"/primary/{self.weights}"] = (200, self.payloads[self.weights], False)
        self.download()
        self.assert_valid_cache()
        self.assertEqual(self.requests[1], (f"/primary/{self.weights}", None))

    def test_oversized_partial_restarts_after_http_416(self):
        (self.cache / f"{self.weights}.0.download").write_bytes(b"x" * 100)
        self.download()
        self.assert_valid_cache()

    def test_expired_certificate_fails_fast_and_preserves_curl_error(self):
        result = subprocess.CompletedProcess([], 60, "000", "SSL certificate problem: certificate has expired")
        with patch.object(setup.subprocess, "run", return_value=result) as run, patch("time.sleep") as sleep:
            with contextlib.redirect_stderr(self.logs):
                self.assertFalse(setup._curl_download("https://expired.example/model", str(self.cache / "part")))
        run.assert_called_once()
        sleep.assert_not_called()
        self.assertIn("certificate has expired", self.logs.getvalue())
        self.assertNotIn("--insecure", run.call_args.args[0])
        self.assertNotIn("-k", run.call_args.args[0])

    def test_tls_failure_falls_back_for_both_files(self):
        real_run = subprocess.run

        def fail_primary(args, **kwargs):
            if "/primary/" in args[-1]:
                return subprocess.CompletedProcess(args, 60, "000", "certificate has expired")
            return real_run(args, **kwargs)

        with patch.object(setup.subprocess, "run", side_effect=fail_primary):
            self.download()
        self.assert_valid_cache()

    def test_timeout_falls_back(self):
        real_run = subprocess.run

        def fail_primary(args, **kwargs):
            if "/primary/" in args[-1]:
                raise subprocess.TimeoutExpired(args, 3600)
            return real_run(args, **kwargs)

        with patch.object(setup.subprocess, "run", side_effect=fail_primary):
            self.download()
        self.assert_valid_cache()
        self.assertIn("timed out", self.logs.getvalue())

    def test_transient_server_error_is_retried(self):
        results = [subprocess.CompletedProcess([], 22, "503", "unavailable"),
                   subprocess.CompletedProcess([], 0, "200", "")]
        with patch.object(setup.subprocess, "run", side_effect=results) as run, patch("time.sleep") as sleep:
            with contextlib.redirect_stderr(self.logs), contextlib.redirect_stdout(self.logs):
                self.assertTrue(setup._curl_download(self.sources[0], str(self.cache / "part")))
        self.assertEqual(run.call_count, 2)
        sleep.assert_called_once_with(5)


if __name__ == "__main__":
    unittest.main()
