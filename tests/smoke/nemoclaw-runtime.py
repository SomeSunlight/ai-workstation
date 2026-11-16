#!/usr/bin/env python3
"""Mock-only contract: NVIDIA upstream WSL Docker qualification; no real runtime."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin/aiw-nemo"


class NativeDockerWslGuard(unittest.TestCase):
    def exercise(self, engine_os, *, gateway_runtime=None):
        with tempfile.TemporaryDirectory(prefix="aiw-nemo-guard-") as root:
            home = Path(root)
            fake_bin = home / "mockbin"
            fake_bin.mkdir()
            (fake_bin / "docker").write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = info ]; then printf '%s\\n' \""
                + engine_os + "\"; fi\n", encoding="utf-8"
            )
            (fake_bin / "nemohermes").write_text(
                "#!/bin/sh\nprintf 'MOCK_NEMO_ONBOARD %s\\n' \"$*\"\n", encoding="utf-8"
            )
            for name in ("docker", "nemohermes"):
                (fake_bin / name).chmod(0o755)
            env = os.environ.copy()
            env["HOME"] = root
            env["PATH"] = str(fake_bin) + os.pathsep + os.environ.get("PATH", "")
            env["WSL_DISTRO_NAME"] = "AIW-Nemo"
            env.pop("NEMOCLAW_GATEWAY_RUNTIME", None)
            if gateway_runtime:
                env["NEMOCLAW_GATEWAY_RUNTIME"] = gateway_runtime
            return subprocess.run(
                ["bash", str(SCRIPT), "onboard", "--resume"],
                env=env, capture_output=True, text=True, timeout=8, check=False,
            )

    def test_native_wsl_docker_stops_before_nemo_or_toolkit(self):
        result = self.exercise("Ubuntu 24.04.4 LTS")
        self.assertEqual(result.returncode, 76, result.stderr)
        self.assertIn("NemoClaw does not qualify native Docker", result.stderr)
        self.assertIn("Podman >= 5", result.stderr)
        self.assertNotIn("MOCK_NEMO_ONBOARD", result.stdout)

    def test_docker_desktop_does_not_trigger_native_gate(self):
        result = self.exercise("Docker Desktop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MOCK_NEMO_ONBOARD onboard --no-gpu --resume", result.stdout)

    def test_explicit_podman_selection_yields_to_upstream_admission(self):
        result = self.exercise("Ubuntu 24.04.4 LTS", gateway_runtime="podman")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MOCK_NEMO_ONBOARD onboard --no-gpu --resume", result.stdout)


if __name__ == "__main__":
    unittest.main()
