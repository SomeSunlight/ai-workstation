#!/usr/bin/env python3
"""Offline, host-neutral regression checks for native supervisor recovery and diagnostics."""
from __future__ import annotations

from contextlib import nullcontext
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("aiw_services", ROOT / "tools" / "aiw-services.py")
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)


class NativeOperationDiagnostics(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name) / "services"
        module.init(self.folder)
        self.file = module.windows_supervisor_state_path(self.folder)
        self.file.parent.mkdir(exist_ok=True)
        self.binary = str(self.folder / "bin" / "process-compose-pilot.exe")
        self.identity = {"pid": 43344, "exe": os.path.normcase(os.path.realpath(self.binary)),
                         "created": "01dd70a6fd056200"}

    def record(self, *, boot="boot-before", ports=None):
        self.file.write_text(json.dumps({
            "identity": self.identity, "boot_id": boot, "port": 19011,
            "service_ports": [8080, 8001] if ports is None else ports,
        }), encoding="utf-8")

    def test_reused_windows_pid_is_silently_archived(self):
        self.record()
        adobe = {"pid": 43344, "exe": r"c:\adobe\desktop.exe", "created": "other"}
        with (mock.patch.object(module, "windows_process_identity", return_value=adobe),
              mock.patch.object(module, "windows_boot_id", return_value="boot-after"),
              mock.patch.object(module, "windows_process_compose_pids", return_value=set()),
              mock.patch.object(module, "windows_all_listeners", return_value=set()) as check,
              mock.patch("sys.stdout", new_callable=io.StringIO) as output):
            self.assertFalse(module.windows_prepare_start(self.folder, self.binary,
                                                          19011, [443, 3000]))
        self.assertFalse(self.file.exists())
        archived = list(self.file.parent.glob(self.file.name + ".stale-*.bak"))
        self.assertEqual(len(archived), 1)
        self.assertEqual(json.loads(archived[0].read_text())["identity"], self.identity)
        self.assertEqual(output.getvalue(), "")  # no operator prompt/scary warning
        self.assertEqual(check.call_args.args[0], [443, 3000, 8001, 8080, 19011])

    def test_exact_existing_supervisor_is_idempotent(self):
        self.record(boot="same-boot")
        with (mock.patch.object(module, "windows_process_identity", return_value=self.identity),
              mock.patch.object(module, "windows_boot_id", return_value="same-boot"),
              mock.patch.object(module, "windows_process_compose_pids") as processes,
              mock.patch.object(module, "windows_all_listeners") as ports,
              mock.patch("sys.stdout", new_callable=io.StringIO) as output):
            self.assertTrue(module.windows_prepare_start(self.folder, self.binary, 19011, [8080]))
        self.assertIn("already running", output.getvalue())
        processes.assert_not_called()
        ports.assert_not_called()
        self.assertTrue(self.file.exists())

    def test_same_pid_exe_from_previous_boot_must_not_be_reused(self):
        self.record()
        with (mock.patch.object(module, "windows_process_identity", return_value=self.identity),
              mock.patch.object(module, "windows_boot_id", return_value="boot-after"),
              mock.patch.object(module, "windows_process_compose_pids", return_value=set()),
              mock.patch.object(module, "windows_all_listeners", return_value=set())):
            self.assertFalse(module.windows_prepare_start(self.folder, self.binary, 19011, []))
        self.assertFalse(self.file.exists())

    def test_live_unknown_supervisor_blocks_start(self):
        self.record()
        with (mock.patch.object(module, "windows_process_identity", return_value=None),
              mock.patch.object(module, "windows_boot_id", return_value="boot-after"),
              mock.patch.object(module, "windows_process_compose_pids", return_value={1234}),
              mock.patch.object(module, "windows_all_listeners") as ports):
            with self.assertRaisesRegex(module.ConfigError, "Process Compose is still running"):
                module.windows_prepare_start(self.folder, self.binary, 19011, [])
        ports.assert_not_called()
        self.assertTrue(self.file.exists())

    def test_busy_service_port_blocks_recovery(self):
        self.record()
        with (mock.patch.object(module, "windows_process_identity", return_value=None),
              mock.patch.object(module, "windows_boot_id", return_value="new"),
              mock.patch.object(module, "windows_process_compose_pids", return_value=set()),
              mock.patch.object(module, "windows_all_listeners", return_value={8080})):
            with self.assertRaisesRegex(module.ConfigError, "8080"):
                module.windows_prepare_start(self.folder, self.binary, 19011, [443])
        self.assertTrue(self.file.exists())

    def test_missing_record_but_untracked_compose_blocks_start(self):
        with mock.patch.object(module, "windows_process_compose_pids", return_value={998}):
            with self.assertRaisesRegex(module.ConfigError, "Untracked"):
                module.windows_prepare_start(self.folder, self.binary, 19011, [])
        self.assertFalse(self.file.exists())

    def test_unavailable_probe_or_invalid_record_must_fail_closed(self):
        self.record()
        with (mock.patch.object(module, "windows_process_identity", return_value=None),
              mock.patch.object(module, "windows_boot_id", return_value=None),
              mock.patch.object(module, "windows_process_compose_pids",
                                side_effect=module.ConfigError("probe failed"))):
            with self.assertRaisesRegex(module.ConfigError, "probe failed"):
                module.windows_prepare_start(self.folder, self.binary, 19011, [])
        self.assertTrue(self.file.exists())
        self.file.write_text("not json")
        with self.assertRaisesRegex(module.ConfigError, "Invalid supervisor"):
            module.windows_prepare_start(self.folder, self.binary, 19011, [])
        self.assertTrue(self.file.exists())

    @unittest.skipIf(os.name == "nt", "Windows symlink creation may need elevated privileges")
    def test_symlinked_state_refused(self):
        target = self.folder / "owner.json"
        target.write_text("{}")
        self.file.symlink_to(target)
        with self.assertRaisesRegex(module.ConfigError, "Linked"):
            module.windows_prepare_start(self.folder, self.binary, 19011, [])
        self.assertEqual(target.read_text(), "{}")

    def test_running_supervisor_does_not_run_preflight_or_start(self):
        with (mock.patch.object(module, "windows_start_lock", return_value=nullcontext()),
              mock.patch.object(module, "windows_prepare_start", return_value=True),
              mock.patch.object(module, "windows_show_existing_status") as status,
              mock.patch.object(module.subprocess, "Popen") as popen):
            probe = mock.Mock()
            module.windows_launch_supervisor(self.folder, self.binary, [], [], 19011,
                                             {}, [8080], preflight=probe)
        probe.assert_not_called()
        popen.assert_not_called()
        status.assert_called_once()

    def test_preflight_remains_mandatory_before_launch(self):
        with (mock.patch.object(module, "windows_start_lock", return_value=nullcontext()),
              mock.patch.object(module, "windows_prepare_start", return_value=False),
              mock.patch.object(module.subprocess, "Popen") as popen):
            probe = mock.Mock(side_effect=module.ConfigError("unsafe preflight"))
            with self.assertRaisesRegex(module.ConfigError, "unsafe preflight"):
                module.windows_launch_supervisor(self.folder, self.binary, [], [], 19011,
                                                 {}, [8080], preflight=probe)
        popen.assert_not_called()

    def test_windows_process_ancestry_rejects_reused_parent_pid(self):
        procs = {
            10: {"pid": 10, "ppid": 1, "name": "process-compose", "created": "2026-11-11T10:00:00Z"},
            11: {"pid": 11, "ppid": 10, "name": "strata", "created": "2026-11-11T10:01:00Z"},
            12: {"pid": 12, "ppid": 10, "name": "strata", "created": "2026-11-10T10:01:00Z"},
        }
        self.assertTrue(module.windows_is_supervised_pid(10, 10, procs))
        self.assertTrue(module.windows_is_supervised_pid(11, 10, procs))
        self.assertFalse(module.windows_is_supervised_pid(12, 10, procs))
        self.assertFalse(module.windows_is_supervised_pid(11, None, procs))

    def test_linux_ss_inventory(self):
        output = ('LISTEN 0 4096 127.0.0.1:8080 0.0.0.0:* '
                  'users:(("python3",pid=123,fd=5))\n'
                  'LISTEN 0 4096 [::]:8001 [::]:* \n')
        result = subprocess.CompletedProcess([], 0, output, "")
        with (mock.patch.object(module.shutil, "which", return_value="/usr/bin/ss"),
              mock.patch.object(module.subprocess, "run", return_value=result)):
            sockets, owners = module.linux_tcp_process_inventory({8080, 8001, 19011})
        self.assertEqual({s["port"] for s in sockets}, {8080, 8001})
        self.assertEqual(owners[123]["name"], "python3")
        self.assertIsNone(next(s["pid"] for s in sockets if s["port"] == 8001))

    def test_cross_platform_port_overview_and_ownership_labels(self):
        host = self.folder / "native-host.json"
        host.write_text(json.dumps({"services": {
            "strata": {"enabled": True, "listen_ports": [8080]},
            "dispatcher": {"enabled": True, "listen_ports": [8001]},
            "caddy": {"enabled": True, "listen_ports": [443]},
        }}))
        connections = [{"port": 19011, "pid": 10}, {"port": 8080, "pid": 11},
                       {"port": 443, "pid": 90}]
        processes = {
            10: {"pid": 10, "ppid": 1, "name": "process-compose", "created": "2026-11-11T10:00:00Z"},
            11: {"pid": 11, "ppid": 10, "name": "strata", "created": "2026-11-11T10:01:00Z"},
            90: {"pid": 90, "ppid": 1, "name": "foreign", "created": "2026-11-11T10:00:00Z"},
        }
        with (mock.patch.object(module, "windows_tcp_process_inventory",
                                return_value=(connections, processes)),
              mock.patch.object(module, "verified_windows_supervisor_pid", return_value=10),
              mock.patch("sys.stdout", new_callable=io.StringIO) as output):
            module.show_service_ports(self.folder, system="nt")
        report = output.getvalue()
        for text in ("supervisor", "strata", "dispatcher", "caddy", "AIW",
                     "CONFLICT", "FREE", "foreign (PID 90)"):
            self.assertIn(text, report)
        self.assertNotIn("Adobe", report)

    def test_existing_supervisor_status_checks_actual_management_port_pid(self):
        with (mock.patch.object(module, "port_accepts_connections", return_value=True),
              mock.patch.object(module, "verified_windows_supervisor_pid", return_value=50),
              mock.patch.object(module, "windows_tcp_process_inventory",
                                return_value=([{"port": 19011, "pid": 91}], {})),
              mock.patch.object(module.subprocess, "run") as run):
            with self.assertRaisesRegex(module.ConfigError, "unverified owner"):
                module.windows_show_existing_status(self.folder, 19011, [], {})
        run.assert_not_called()

    def test_windows_listener_probe_fails_closed(self):
        with mock.patch.object(module.subprocess, "run",
                               return_value=subprocess.CompletedProcess([], 1, "", "")):
            with self.assertRaisesRegex(module.ConfigError, "Cannot inspect Windows"):
                module.windows_tcp_process_inventory({8080})


if __name__ == "__main__":
    unittest.main(verbosity=2)
