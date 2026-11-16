#!/usr/bin/env python3
"""Offline contracts only: never touch real WSL, Docker, Podman or NemoClaw."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NemoPodmanProfileContracts(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_immutable_ubuntu_and_podman_identity(self):
        versions = json.loads(self.read("config/versions.json"))["versions"]
        self.assertEqual(versions["ubuntu"]["release"], "24.04")
        nemo = versions["nemoclaw_podman"]
        self.assertEqual(nemo["ubuntu"]["release"], "26.04")
        self.assertEqual(nemo["podman"]["apt_package_version"], "5.7.0+ds2-3build1")
        self.assertEqual(nemo["podman"]["minimum_version"], "5.0.0")
        self.assertEqual(nemo["ubuntu"]["wsl_image_sha256"],
                         "48d56724b5c8e60f24893e83e73bbb58c60b3ca22fba3da977075420acd54104")

    def test_legacy_install_remains_default_and_ubuntu26_is_opt_in(self):
        linux = self.read("bootstrap/linux/install.sh")
        self.assertIn('INSTALL_PROFILE="legacy"', linux)
        self.assertIn('nemoclaw-podman', linux)
        self.assertIn('versions.nemoclaw_podman.ubuntu.release', linux)
        self.assertIn('ansible/playbooks/nemoclaw.yml', linux)
        self.assertIn('python install 3.12', linux)
        self.assertIn('ansible/playbooks/nemoclaw-bootstrap-verify.yml', linux)

    def test_podman_only_ansible_and_official_vendor_authority(self):
        playbook = self.read("ansible/playbooks/nemoclaw.yml")
        self.assertIn("role: nemoclaw_podman", playbook)
        self.assertIn("role: nemoclaw_host", playbook)
        self.assertNotIn("role: docker_engine", playbook)
        role = self.read("ansible/roles/nemoclaw_podman/tasks/main.yml")
        for keyword in ["podman=", "netavark", "aardvark-dns",
                        "enable-linger", "podman.socket", "rootless"]:
            self.assertIn(keyword, role)
        upstream = self.read("ansible/roles/nemoclaw_host/tasks/main.yml")
        self.assertIn("NEMOCLAW_GATEWAY_RUNTIME: podman", upstream)
        self.assertIn("--defer-onboarding", upstream)
        self.assertNotIn("openshell sandbox create", upstream)

    def test_onboard_uses_selected_runtime_and_remote_no_gpu(self):
        menu = self.read("bin/aiw-nemo")
        self.assertIn("export NEMOCLAW_GATEWAY_RUNTIME=podman", menu)
        self.assertIn('nemohermes onboard --no-gpu "$@"', menu)
        self.assertIn("podman.socket", menu)
        self.assertNotIn("docker info", menu)

    def test_windows_guard_and_owner_cleanup_are_separate(self):
        entry = self.read("install-nemoclaw.ps1")
        self.assertIn("Profile = 'NemoPodman'", entry)
        self.assertIn("DistroName = 'AIW-Nemo'", entry)
        platform = self.read("bootstrap/windows/Install-AiWorkstation.ps1")
        self.assertIn("versions.nemoclaw_podman.ubuntu", platform)
        self.assertIn('nemoclaw-podman', platform)
        self.assertIn("Preserving global .wslconfig", platform)
        self.assertIn("Invoke-AiwObservedWslImport", platform)
        deletion = self.read("bootstrap/windows/Remove-OldNemoWsl.ps1")
        self.assertIn("DELETE AIW-Nemo", deletion)
        self.assertIn("VERSION_ID", deletion)
        self.assertIn("--unregister", deletion)
        self.assertNotIn("wsl --shutdown", deletion)

    def test_official_documentation_and_split_plan_not_checklist(self):
        guide = self.read("docs/nemoclaw-podman.md")
        self.assertIn("Podman", guide)
        self.assertIn("OpenRouter", guide)
        self.assertNotIn("- [ ]", guide)
        split = self.read("docs/architecture-repo-split.md")
        self.assertIn("ai-workstation-linux", split)


if __name__ == "__main__":
    unittest.main()
