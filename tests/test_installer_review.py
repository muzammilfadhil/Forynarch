"""Non-executable installer metadata and driver policy, with synthetic inventory."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix" and shutil.which("jq"), "Linux jq required")
class InstallerReview(unittest.TestCase):
    def setUp(self):
        self.request = dict(locale="en_US.UTF-8", timezone="UTC", keyboard="us", offline=True,
                            selectedDrivers=[], username="qauser", hostname="qa-host")
        self.info = dict(timezones=["UTC", "Asia/Jakarta"], graphics=[dict(vendor="0x8086")],
                         drivers=json.loads((ROOT / "packages/driver-catalog.json").read_text()))

    def review(self, **changes):
        request = {**self.request, **changes}
        return subprocess.run(["jq", "--argjson", "request", json.dumps(request),
                               "--argjson", "info", json.dumps(self.info), "-f",
                               str(ROOT / "scripts/installer-review.jq")],
                              input=json.dumps(dict(blockers=["No executor"], optionalPackages=[])),
                              text=True, capture_output=True)

    def test_core_only_and_english_locale(self):
        result = self.review()
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertFalse(plan["canExecute"])
        self.assertEqual(plan["driverPackages"], [])
        self.assertEqual(plan["system"]["locale"], "en_US.UTF-8")

    def test_explicit_driver_packages_without_developer_tools(self):
        result = self.review(offline=False, selectedDrivers=["intel-vulkan", "intel-vulkan"])
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["driverPackages"], ["vulkan-intel"])
        self.assertFalse(plan["canExecute"])
        self.assertGreater(len(plan["blockers"]), 1)

    def test_rejects_offline_unknown_and_mismatched_drivers(self):
        for changes in [dict(selectedDrivers=["intel-vulkan"]),
                        dict(offline=False, selectedDrivers=["unknown"]),
                        dict(offline=False, selectedDrivers=["amd-vulkan"]),
                        dict(selectedDrivers="intel-vulkan")]:
            with self.subTest(changes=changes):
                self.assertNotEqual(self.review(**changes).returncode, 0)

    def test_nvidia_never_inferred_from_vendor_alone(self):
        self.info["graphics"] = [dict(vendor="0x10de")]
        self.assertNotEqual(self.review(offline=False, selectedDrivers=["nvidia"]).returncode, 0)

    def test_secrets_rejected(self):
        for field in ["password", "confirmation"]:
            result = self.review(**{field: "synthetic-secret"})
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("synthetic-secret", result.stderr + result.stdout)

    def test_location_and_keyboard_allowlists(self):
        for changes in [dict(timezone="../../etc/shadow"), dict(keyboard="unknown"), dict(locale="id_ID.UTF-8")]:
            self.assertNotEqual(self.review(**changes).returncode, 0)

    def test_no_input_mutation(self):
        before = copy.deepcopy((self.request, self.info))
        self.review()
        self.assertEqual((self.request, self.info), before)
