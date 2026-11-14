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
        with patch.object(module, "openshell",
                          side_effect=lambda *args, capture=False: "/home/goose" if capture else "") as cli:
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
            self.assertIn("/home/goose/project", cli.call_args.args)
            self.assertTrue(any(call.kwargs.get("capture") for call in cli.call_args_list))
            with self.assertRaises(module.Refused):
                module.goose(entry, "https://example.invalid", "work", directory="../etc")

    def test_goose_refuses_unknown_workdir_without_launch(self):
        entry = {"name": "internal", "title": "Display", "phase": "Ready"}
        with patch.object(module, "openshell", return_value="/") as cli:
            with self.assertRaises(module.Refused):
                module.goose(entry, "https://example.invalid", "work", directory="project")
            self.assertEqual(cli.call_count, 1)

    def test_public_site_validation_and_restrictive_https_rule(self):
        self.assertEqual(module.website_hostname("https://docs.python.org/3/library"),
                         "docs.python.org")
        for bad in ("", "http://example.com", "https://user:secret@example.com",
                    "https://localhost", "https://private.local", "https://10.1.2.3",
                    "https://example.org:8443", "https://*.example.org"):
            with self.assertRaises(module.Refused, msg=bad):
                module.website_hostname(bad)
        text = module.website_policy("docs.python.org")
        self.assertIn('host: "docs.python.org"', text)
        self.assertIn("enforcement: enforce", text)
        self.assertIn("access: read-only", text)
        self.assertIn("landlock:" + chr(10) + "  compatibility: hard_requirement", text)
        self.assertNotIn("approval_mode: auto", text)
        self.assertNotIn("0.0.0.0/0", text)

    def test_creation_defaults_to_bundled_research_policy(self):
        with patch.object(module, "list_workstations", return_value=[]), \
             patch.object(module, "openshell") as cli, \
             patch("builtins.input", return_value="CREATE"):
            module.create("OpenShellGooseTest01")
        args = cli.call_args.args
        self.assertIn(str(module.RESTRICTED_POLICY), args)
        self.assertIn("aiw.profile=restricted", args)
        self.assertNotIn("--approval-mode", args)
        self.assertNotIn("--mount", args)

    def test_site_policy_is_temporary_and_remains_read_only(self):
        captured = []
        def fake(*args, capture=False):
            captured.append((args, args[-1]))
            path = Path(args[-1])
            if path.is_file():
                captured.append((path.read_text(), path.stat().st_mode & 0o777))
            return ""
        with patch.object(module, "list_workstations", return_value=[]), \
             patch.object(module, "openshell", side_effect=fake), \
             patch("builtins.input", return_value="CREATE"):
            module.create("Research", profile="website", website="https://docs.python.org/3/")
        args, _ = captured[0]
        self.assertIn("aiw.profile=website", args)
        self.assertIn("aiw.site=docs.python.org", args)
        self.assertIn("--policy", args)
        self.assertIn('host: "docs.python.org"', captured[1][0])
        self.assertEqual(captured[1][1], 0o600)
        self.assertFalse(Path(args[-1]).exists(), "No persistent AIW-generated policy files")

    def test_flexible_auto_mode_needs_explicit_approval(self):
        with patch.object(module, "list_workstations", return_value=[]), \
             patch.object(module, "openshell") as cli:
            with patch("builtins.input", return_value="CREATE"):
                module.create("Research", profile="flexible")
            cli.assert_not_called()
            with patch("builtins.input", return_value="ALLOW"):
                module.create("Research", profile="flexible")
            args = cli.call_args.args
            self.assertIn("--approval-mode", args)
            self.assertEqual(args[args.index("--approval-mode")+1], "auto")
            self.assertIn(str(module.RESTRICTED_POLICY), args)
            self.assertNotIn("--mount", args)
        with self.assertRaises(module.Refused):
            module.create("Bad", profile="restricted", website="https://example.org")
        with self.assertRaises(module.Refused):
            module.create("Bad", profile="website")

    def test_menu_default_does_not_ask_for_yaml_paths(self):
        with patch.object(module, "require_runtime"), \
             patch.object(module, "list_workstations", return_value=[]), \
             patch.object(module, "choose", side_effect=["create", "restricted", None]), \
             patch.object(module, "openshell") as cli, \
             patch("builtins.input", side_effect=["OpenShellGooseTest01", "CREATE"]) as prompt:
            module.menu()
        self.assertEqual(prompt.call_count, 2)
        self.assertEqual(cli.call_count, 1)
        self.assertIn("aiw.profile=restricted", cli.call_args.args)

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
