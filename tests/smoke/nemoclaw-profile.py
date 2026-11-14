#!/usr/bin/env python3
"""Offline contracts only: do not start Docker, WSL, OpenShell or NemoClaw."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NemoClawProfileContracts(unittest.TestCase):
    def text(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_native_install_is_opt_in_and_preserves_legacy(self):
        linux = self.text("bootstrap/linux/install.sh")
        self.assertIn('INSTALL_PROFILE="legacy"', linux)
        self.assertIn('"$INSTALL_PROFILE" == "nemoclaw"', linux)
        self.assertIn('ansible/playbooks/nemoclaw.yml', linux)
        self.assertIn('bin/aiw" install', linux)
        self.assertNotIn("wsl --unregister", linux)
        windows = self.text("bootstrap/windows/Install-AiWorkstation.ps1")
        self.assertIn("if ($Profile -eq 'Legacy')", windows)
        self.assertIn("Preserving global .wslconfig", windows)
        self.assertIn("not marked as the NemoClaw profile", windows)

    def test_new_role_leaves_agent_authority_to_upstream(self):
        playbook = self.text("ansible/playbooks/nemoclaw.yml")
        self.assertIn("docker_engine", playbook)
        self.assertIn("nemoclaw_host", playbook)
        self.assertNotIn("project_directories", playbook)
        role = self.text("ansible/roles/nemoclaw_host/tasks/main.yml")
        self.assertIn("NEMOCLAW_AGENT: hermes", role)
        self.assertIn("NEMOCLAW_INSTALL_REF:", role)
        self.assertIn("NEMOCLAW_DISABLE_TELEMETRY:", role)
        self.assertIn("--defer-onboarding", role)
        self.assertIn("not nemo_cli_stat.stat.exists", role)
        self.assertNotIn("openshell sandbox create", role)
        self.assertNotIn("curl -fsSL", role)
        self.assertNotIn("docker-desktop", role)

    def test_pinned_nemoclaw_and_no_old_wsl_deletion(self):
        defaults = self.text("ansible/roles/nemoclaw_host/defaults/main.yml")
        self.assertIn("82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f", defaults)
        wrapper = self.text("install-nemoclaw.ps1")
        self.assertIn("Profile = 'NemoClaw'", wrapper)
        self.assertIn("DistroName = 'AIW-Nemo'", wrapper)
        self.assertNotIn("--unregister", wrapper)
        creator = self.text("bootstrap/windows/Create-NemoClawShortcut.ps1")
        self.assertNotIn("Remove-Item", creator)
        self.assertIn("nemoclaw-hermes.ico", creator)
        self.assertTrue((ROOT / "bootstrap/windows/nemoclaw-hermes.ico").is_file())

    def test_checklist_is_real_and_starts_unchecked(self):
        checklist = self.text("docs/nemoclaw-acceptance.md")
        self.assertGreaterEqual(checklist.count("- [ ]"), 25)
        self.assertIn("Second run", checklist)
        self.assertIn("OpenRouter", checklist)
        self.assertIn("private", checklist.lower())
        self.assertIn("Docker Desktop", checklist)


if __name__ == "__main__":
    unittest.main()
