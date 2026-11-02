#!/usr/bin/env python3
"""Focused tests: native service config, private named S02 credentials and CLI."""
from __future__ import annotations

import hashlib
import io
import tarfile
import urllib.error
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "aiw-services.py"
spec = importlib.util.spec_from_file_location("aiw_services", SOURCE)
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)


class TestNativeServices(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name) / "services"
        module.init(self.folder)

    def test_safe_scaffold(self):
        doc = module.read_settings(self.folder)
        self.assertEqual(doc["clients"], {})
        self.assertEqual(doc["process_compose"]["port"], 19011)
        self.assertIn("disabled: true", module.project_path(self.folder, doc).read_text())
        self.assertNotIn("8080", module.project_path(self.folder, doc).read_text())
        self.assertEqual(stat.S_IMODE(self.folder.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(module.settings_path(self.folder).stat().st_mode), 0o600)
        self.assertTrue((self.folder / "secrets" / "process-compose.api-token").is_file())
        with self.assertRaises(module.ConfigError):
            module.init(self.folder)

    def test_named_clients_and_safe_hash_only_json(self):
        module.client_add(self.folder, "goose-laptop", "passthrough")
        module.client_add(self.folder, "webui-speedy", "default")
        token = module.read_secret(self.folder, "goose-laptop")
        self.assertGreaterEqual(len(token), 40)
        module.client_render(self.folder, self.folder / "clients.json")
        raw = (self.folder / "clients.json").read_text()
        self.assertNotIn(token, raw)
        self.assertEqual(stat.S_IMODE((self.folder / "clients.json").stat().st_mode), 0o600)
        data = json.loads(raw)
        self.assertEqual(data["schema_version"], 1)
        self.assertEqual([x["id"] for x in data["clients"]], ["goose-laptop", "webui-speedy"])
        self.assertEqual(data["clients"][0]["token_sha256"], hashlib.sha256(token.encode()).hexdigest())
        with self.assertRaises(module.ConfigError):
            module.client_add(self.folder, "goose-laptop", "enforce")
        module.client_remove(self.folder, "goose-laptop")
        module.client_render(self.folder, self.folder / "clients.json")
        self.assertEqual(json.loads((self.folder / "clients.json").read_text())["clients"][0]["id"],
                         "webui-speedy")
        self.assertEqual(module.read_secret(self.folder, "goose-laptop"), token)

    def test_rename_preserves_secret_and_rejects_collisions(self):
        module.client_add(self.folder, "goose-laptop", "passthrough")
        module.client_add(self.folder, "webui-private", "default")
        old_secret = module.read_secret(self.folder, "goose-laptop")
        module.client_rename(self.folder, "goose-laptop", "goose-research")
        cfg = module.read_settings(self.folder)
        self.assertEqual(list(cfg["clients"]), ["goose-research", "webui-private"])
        self.assertEqual(cfg["clients"]["goose-research"]["policy"], "passthrough")
        self.assertEqual(module.read_secret(self.folder, "goose-research"), old_secret)
        self.assertFalse(module.secret_file(self.folder, "goose-laptop").exists())
        with self.assertRaises(module.ConfigError):
            module.client_rename(self.folder, "goose-research", "webui-private")
        with self.assertRaises(module.ConfigError):
            module.client_rename(self.folder, "goose-research", "../unsafe")
        module.client_render(self.folder, self.folder / "clients.json")
        rendered = json.loads((self.folder / "clients.json").read_text())
        self.assertEqual(rendered["clients"][0]["id"], "goose-research")
        self.assertEqual(rendered["clients"][0]["token_sha256"],
                         hashlib.sha256(old_secret.encode()).hexdigest())

    def test_clipboard_transfer_unavailable_on_linux(self):
        module.client_add(self.folder, "goose-research", "passthrough")
        with mock.patch.object(module.os, "name", "posix"):
            with self.assertRaisesRegex(module.ConfigError, "Windows-only"):
                module.client_copy(self.folder, "goose-research")

    def test_fail_closed_and_private_paths(self):
        with self.assertRaises(module.ConfigError):
            module.client_render(self.folder, self.folder / "clients.json")
        with self.assertRaises(module.ConfigError):
            module.client_add(self.folder, "../evil", "default")
        with self.assertRaises(module.ConfigError):
            module.client_add(self.folder, "goose-laptop", "anything")
        module.client_add(self.folder, "goose-laptop", "enforce")
        token = module.secret_file(self.folder, "goose-laptop")
        token.chmod(0o644)
        with self.assertRaises(module.ConfigError):
            module.client_render(self.folder, self.folder / "clients.json")
        token.chmod(0o600)
        with self.assertRaises(module.ConfigError):
            module.client_render(self.folder, Path(self.tmp.name) / "outside.json")
        doc = module.read_settings(self.folder)
        doc["process_compose"]["port"] = 8080
        module.save_settings(self.folder, doc)
        with self.assertRaises(module.ConfigError):
            module.read_settings(self.folder)

    def test_native_client_passes_only_loopback_auth_and_config(self):
        stub = Path(self.tmp.name) / "fake-process-compose"
        log = Path(self.tmp.name) / "argv.txt"
        stub.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$AIW_ARGV_LOG\"\n")
        stub.chmod(0o700)
        with mock.patch.dict(os.environ, {
            "AIW_PROCESS_COMPOSE_BIN": str(stub),
            "AIW_ARGV_LOG": str(log)
        }):
            module.native(self.folder, "check", None)
            args = log.read_text().splitlines()
            self.assertIn("--dry-run", args)
            self.assertIn("--disable-dotenv", args)
            # The check uses PC_LOG_LEVEL=warn to hide benign global-config
            # discovery debug messages; the real explicit project stays intact.
            self.assertIn("127.0.0.1", args)
            self.assertIn("127.0.0.1", args)
            self.assertIn("19011", args)
            self.assertIn("--token-file", args)
            module.native(self.folder, "status", None)
            self.assertEqual(log.read_text().splitlines()[-2:], ["process", "list"])
            module.native(self.folder, "up", None)
            self.assertIn("--detached", log.read_text())
            # Unpatched upstream Go binary is intentionally restricted to
            # our isolated, harmless fixture until a verified rebuilt binary.
            project = module.project_path(self.folder, module.read_settings(self.folder))
            project.write_text("version: '0.5'\nprocesses:\n  strata:\n    command: 'strata'\n")
            with self.assertRaises(module.ConfigError):
                module.native(self.folder, "up", None)
            # Non-mutating dry-run remains available for reviewing a candidate.
            module.native(self.folder, "check", None)

    def test_release_download_diagnostics_and_offline_archive_verification(self):
        http_error = urllib.error.HTTPError("https://github.com/release", 403,
                                            "Forbidden", {}, None)
        self.assertEqual(module.download_failure_reason(http_error), "HTTP 403")
        with mock.patch.object(module.urllib.request, "urlopen", side_effect=http_error):
            with self.assertRaisesRegex(module.ConfigError, "HTTP 403"):
                module.download_release("https://github.com/release", self.folder)

        archive_path = Path(self.tmp.name) / "official-process-compose.tar.gz"
        with tarfile.open(archive_path, "w:gz") as tar:
            content = b"#!/bin/sh\\necho fixture\\n"
            info = tarfile.TarInfo("process-compose")
            info.mode = 0o755
            info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
        digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        with mock.patch.object(module, "pinned_release",
                               return_value=("v1.124.0", "process-compose_linux_amd64.tar.gz", digest)):
            module.install_process_compose(self.folder, archive_path)
        exe = self.folder / "bin" / "process-compose"
        self.assertTrue(exe.is_file())
        self.assertEqual(exe.read_bytes(), content)
        with self.assertRaisesRegex(module.ConfigError, "already"):
            module.install_process_compose(self.folder, archive_path)

        other = Path(self.tmp.name) / "other-services"
        other.mkdir()
        bad_path = Path(self.tmp.name) / "wrong.tar.gz"
        bad_path.write_bytes(b"unverified")
        with mock.patch.object(module, "pinned_release",
                               return_value=("v1.124.0", "process-compose_linux_amd64.tar.gz", digest)):
            with self.assertRaisesRegex(module.ConfigError, "SHA-256 mismatch"):
                module.install_process_compose(other, bad_path)
        self.assertFalse((other / "bin" / "process-compose").exists())

    def test_symlink_disallowed(self):
        target = Path(self.tmp.name) / "bad-secret"
        target.write_text("secret")
        token = module.secret_file(self.folder, "goose-laptop")
        token.parent.mkdir(exist_ok=True)
        token.symlink_to(target)
        with self.assertRaises(module.ConfigError):
            module.client_add(self.folder, "goose-laptop", "passthrough")


if __name__ == "__main__":
    unittest.main(verbosity=2)
