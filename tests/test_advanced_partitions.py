"""Launcher boundary tests using stub commands; never touch block devices."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "Linux Bash required")
class AdvancedPartitions(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name)
        self.stub("id", "printf '1000\\n'")
        self.stub("partitionmanager", "printf 'EDITOR_OPENED\\n'; for arg in \"$@\"; do printf '%s\\n' \"$arg\"; done")

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run([shutil.which("bash"), str(ROOT / "scripts/forynarch-partitions.sh"), *args],
                              env={**os.environ, "PATH": str(self.bin)}, capture_output=True, text=True)

    def test_capability_and_missing_editor(self):
        self.assertTrue(json.loads(self.run_helper("status").stdout)["available"])
        (self.bin / "partitionmanager").unlink()
        self.assertFalse(json.loads(self.run_helper("status").stdout)["available"])
        result = self.run_helper("open")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not installed", result.stderr)

    def test_open_has_no_disk_arguments(self):
        result = self.run_helper("open")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = result.stdout.splitlines()
        self.assertEqual(args[0], "EDITOR_OPENED")
        self.assertIn(args[1:], [[], ["-stylesheet", "/usr/share/forynarch/partition-manager.qss"]])

    def test_rejects_disk_and_operation_arguments(self):
        for args in [("open", "/dev/sda"), ("status", "/dev/sda"), ("format",)]:
            result = self.run_helper(*args)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("EDITOR_OPENED", result.stdout)

    def test_root_must_use_desktop_session(self):
        self.stub("id", "printf '0\\n'")
        result = self.run_helper("open")
        self.assertEqual(result.returncode, 1)
        self.assertIn("desktop session", result.stderr)
        self.assertNotIn("EDITOR_OPENED", result.stdout)
