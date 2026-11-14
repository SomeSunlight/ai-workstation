#!/usr/bin/env python3
"""Offline contracts for the thin OpenShell adapter: never contacts a runtime."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

script = Path(__file__).resolve().parents[2] / "tools/agent_workstations.py"
spec = importlib.util.spec_from_file_location("agent_workstations", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WorkstationTests(unittest.TestCase):
    def test_title_internal_name(self):
        title = "Explore the project"
        self.assertEqual(module.sandbox_name(title), module.sandbox_name(title))
        self.assertTrue(module.sandbox_name(title).startswith("aiw-goose-"))
        with self.assertRaises(module.Refused):
            module.sandbox_name("")

    def test_list_pagination_and_human_titles(self):
        calls = []
        def fake(*args, capture=False):
            calls.append(args)
            if "--page-token" in args:
                return json.dumps({"sandboxes": [{"name": "internal2",
                    "annotations": {"aiw.title": "Research"}, "phase": "Stopped"}]})
            return json.dumps({"sandboxes": [{"name": "internal1",
                "annotations": {"aiw.title": "My Workstation"}, "status": {"phase": "Ready"}}],
                "next_page_token": "token"})
        with patch.object(module, "openshell", side_effect=fake):
            items = module.list_workstations()
        self.assertEqual([x["title"] for x in items], ["My Workstation", "Research"])
        self.assertEqual(module.select_workstation("my workstation", items)["name"], "internal1")
        self.assertIn("--page-token", calls[1])

    def test_bad_list_and_ambiguous_names_refused(self):
        for payload in ('{"error":"fail"}', '{"sandboxes":[{}]}',
                        '{"sandboxes":[],"next_page_token":"loop"}'):
            with patch.object(module, "openshell", return_value=payload):
                with self.assertRaises(module.Refused):
                    module.list_workstations()
        with self.assertRaises(module.Refused):
            module.select_workstation("same", [
                {"title": "Same", "name": "a"}, {"title": "same", "name": "b"}])

    def test_create_needs_typed_approval_and_policy(self):
        with tempfile.TemporaryDirectory() as folder:
            policy = Path(folder) / "strict.yaml"
            policy.write_text("landlock:\n  compatibility: hard_requirement\n")
            with patch.object(module, "list_workstations", return_value=[]), patch.object(module, "openshell") as cli:
                with patch("builtins.input", return_value=""):
                    module.create("New Workstation", str(policy))
                cli.assert_not_called()
                with patch("builtins.input", return_value="CREATE"):
                    module.create("New Workstation", str(policy))
                argv = cli.call_args.args
                self.assertEqual(argv[:2], ("sandbox", "create"))
                self.assertIn("--policy", argv)
                self.assertIn("--label", argv)
                self.assertIn("--annotation", argv)
                self.assertIn("--from", argv)
                self.assertNotIn("--mount", argv)

    def test_export_refuses_overwrite_traversal(self):
        entry = {"name": "internal", "title": "Display", "phase": "Ready"}
        with tempfile.TemporaryDirectory() as folder:
            existing = Path(folder) / "existing"
            existing.write_text("safe")
            with patch.object(module, "openshell") as cli:
                for remote, target in (("../etc/passwd", Path(folder) / "new"),
                                       ("/etc/passwd", Path(folder) / "new"),
                                       ("README.md", existing)):
                    with self.assertRaises(module.Refused):
                        module.export_path(entry, remote, str(target))
                cli.assert_not_called()
                self.assertEqual(existing.read_text(), "safe")
                with patch("builtins.input", return_value="EXPORT"):
                    module.export_path(entry, "src/readme.md", str(Path(folder) / "new"))
                self.assertEqual(cli.call_args.args[:3], ("sandbox", "download", "internal"))

    def test_registered_project_is_complete_copy_no_mount(self):
        entry = {"name": "internal", "title": "Display", "phase": "Ready"}
        with tempfile.TemporaryDirectory() as folder:
            project = Path(folder) / "project"
            project.mkdir()
            with patch.object(module, "registered_projects", return_value=[("project", project)]), \
                 patch.object(module, "openshell") as cli, \
                 patch.object(module.subprocess, "run") as preflight:
                preflight.return_value.returncode = 0
                with patch("builtins.input", return_value=""):
                    module.import_project(entry, "project")
                cli.assert_not_called()
                with patch("builtins.input", return_value="COPY"):
                    module.import_project(entry, "project")
                self.assertEqual(cli.call_args.args,
                                 ("sandbox", "upload", "internal", str(project), "--no-git-ignore"))

    def test_goose_https_and_no_key_in_arguments(self):
        entry = {"name": "internal", "title": "Display", "phase": "Ready"}
        with patch.object(module, "openshell") as cli:
            for invalid in ("http://example.invalid", "https://user:pw@example.invalid"):
                with self.assertRaises(module.Refused):
                    module.goose(entry, invalid, "work")
            cli.assert_not_called()
            module.goose(entry, "https://example.invalid", "work")
            args = cli.call_args.args
            self.assertIn("--tty", args)
            self.assertIn("GOOSE_MODE=approve", args)
            self.assertNotIn("OPENAI_API_KEY", str(args))
            module.goose(entry, "https://example.invalid", "work", directory="project")
            self.assertIn("--workdir", cli.call_args.args)
            self.assertIn("/sandbox/project", cli.call_args.args)
            with self.assertRaises(module.Refused):
                module.goose(entry, "https://example.invalid", "work", directory="../etc")

    def test_no_implicit_start_and_stop_requires_approval(self):
        entry = {"name": "internal", "title": "Display", "phase": "Ready"}
        with patch.object(module, "openshell") as cli:
            module.start(entry)
            cli.assert_not_called()
            with patch("builtins.input", return_value=""):
                module.stop(entry)
            cli.assert_not_called()
            with patch("builtins.input", return_value="STOP"):
                module.stop(entry)
            self.assertEqual(cli.call_args.args, ("sandbox", "stop", "internal"))


if __name__ == "__main__":
    unittest.main()
