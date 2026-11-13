#!/usr/bin/env python3
"""Offline Issue #68 preflight contract tests. Never probe the user's host."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import openshell_preflight as preflight


class OfflinePreflightTests(unittest.TestCase):
    def setUp(self):
        self.sample = preflight.example_capabilities()

    def test_example_is_entirely_host_independent_and_never_writes(self):
        with (mock.patch.object(preflight, "collect_capabilities",
                                side_effect=AssertionError("host accessed")),
              mock.patch.object(preflight, "_read_fixed",
                                side_effect=AssertionError("file accessed")),
              mock.patch.object(preflight, "_syscall_query",
                                side_effect=AssertionError("kernel accessed")),
              mock.patch("builtins.open", side_effect=AssertionError("file opened")),
              mock.patch.object(os, "system", side_effect=AssertionError("shell called")),
              contextlib.redirect_stdout(io.StringIO()) as output):
            self.assertEqual(preflight.main(["--example", "--json"]), 0)
        report = json.loads(output.getvalue())
        self.assertEqual(report["mode"], "example")
        self.assertTrue(report["synthetic"])
        self.assertFalse(report["compatibility_certified"])
        self.assertEqual(report["passive_verdict"], "INCOMPLETE")
        self.assertEqual(report["schema_version"], "1.0")

    def test_kernel_major_minor_and_host_secrets_are_never_echoed(self):
        raw = dict(self.sample, kernel=(6, 6), distro="user@corporate",
                   distro_version="very-sensitive", arch="/private/path",
                   environment="secret-tenant", self_nnp="some-secret",
                   landlock_abi="hello-secret", user_notif="credential")
        text = json.dumps(preflight.evaluate(raw), sort_keys=True)
        for token in ("user@corporate", "very-sensitive", "/private/path",
                      "secret-tenant", "some-secret", "hello-secret",
                      "credential"):
            self.assertNotIn(token, text)
        self.assertIn("other-or-unavailable", text)
        self.assertIn("query-not-conclusive", text)
        self.assertNotIn("hostname", text)

    def test_all_statuses_bounded_and_unknown_not_upgraded_to_go(self):
        result = preflight.evaluate(self.sample)
        self.assertEqual(result["passive_verdict"], "INCOMPLETE")
        checks = {c["id"]: c for c in result["checks"]}
        self.assertEqual(checks["landlock_abi"]["status"], "PASS")
        self.assertEqual(checks["seccomp_user_notif_action"]["status"], "PASS")
        for key in ("seccomp_runtime_enforcement", "task_memory_access",
                    "socket_bind_to_device", "no_new_privs_runtime"):
            self.assertEqual(checks[key]["status"], "UNKNOWN")
        self.assertEqual(checks["runtime_install_approval"]["status"],
                         "POLICY-APPROVAL-NEEDED")
        self.assertEqual(checks["wsl_host_boundary"]["status"],
                         "POLICY-APPROVAL-NEEDED")
        for c in result["checks"]:
            self.assertIn(c["status"], preflight.STATUSES)

    def test_landlock_missing_or_below_three_blocks(self):
        for value in (0, 1, 2, "unavailable"):
            with self.subTest(value=value):
                raw = dict(self.sample, landlock_abi=value)
                result = preflight.evaluate(raw)
                self.assertEqual(result["passive_verdict"], "BLOCKED")
                check = next(c for c in result["checks"] if c["id"] == "landlock_abi")
                self.assertEqual(check["status"], "FAIL")

    def test_missing_container_sockets_are_unknown_not_install_instruction(self):
        raw = dict(self.sample, docker_client=False, docker_socket=False,
                   podman_client=False, podman_socket=False, cgroup2=False)
        checks = {c["id"]: c for c in preflight.evaluate(raw)["checks"]}
        for key in ("docker_client", "docker_socket", "podman_client",
                    "podman_socket", "cgroups_v2"):
            self.assertEqual(checks[key]["status"], "UNKNOWN")
        self.assertNotIn("sudo", preflight.format_human(preflight.evaluate(raw)).lower())

    def test_seccomp_query_is_non_installing_get_action_avail(self):
        with mock.patch.object(preflight, "_syscall_query", return_value=(0, 0)) as query:
            self.assertTrue(preflight._seccomp_user_notification("x86_64"))
        args = query.call_args.args
        self.assertEqual(args[0], 317)
        self.assertEqual(args[1].value, preflight.SECCOMP_GET_ACTION_AVAIL)
        self.assertEqual(args[2].value, 0)
        with mock.patch.object(preflight, "_syscall_query", return_value=(-1, 1)):
            self.assertIsNone(preflight._seccomp_user_notification("aarch64"))
        with mock.patch.object(preflight, "_syscall_query") as query:
            self.assertIsNone(preflight._seccomp_user_notification("other"))
            query.assert_not_called()

    def test_landlock_query_only_asks_for_abi_version(self):
        with mock.patch.object(preflight, "_syscall_query", return_value=(5, 0)) as query:
            self.assertEqual(preflight._landlock_abi("aarch64"), 5)
        args = query.call_args.args
        self.assertEqual(args[0], 444)
        self.assertEqual(args[1].value, None)
        self.assertEqual(args[2].value, 0)
        self.assertEqual(args[3].value, preflight.LANDLOCK_CREATE_RULESET_VERSION)

    def test_only_allowlisted_capability_files_read(self):
        with self.assertRaises(ValueError):
            preflight._read_fixed("/etc/shadow")

    def test_live_mode_cli_uses_injected_capabilities_only(self):
        with (mock.patch.object(preflight, "collect_capabilities",
                                return_value=self.sample) as collect,
              contextlib.redirect_stdout(io.StringIO()) as output):
            self.assertEqual(preflight.main(["--json"]), 0)
        collect.assert_called_once_with()
        report = json.loads(output.getvalue())
        self.assertFalse(report["synthetic"])
        self.assertEqual(report["mode"], "passive")

    def test_bad_os_and_missing_query_cannot_claim_compatibility(self):
        raw = dict(self.sample, system="other", user_notif=None, landlock_abi=None)
        report = preflight.evaluate(raw)
        self.assertEqual(report["passive_verdict"], "BLOCKED")
        self.assertFalse(report["compatibility_certified"])
        self.assertEqual(
            next(c["status"] for c in report["checks"] if c["id"] == "linux_host"),
            "FAIL")


if __name__ == "__main__":
    unittest.main()
