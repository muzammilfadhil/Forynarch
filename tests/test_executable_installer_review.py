"""The graphical executor must retain every storage safety blocker."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = "Installation is not available in this preview. No partitions or boot entries will be changed."


@unittest.skipUnless(os.name == "posix" and shutil.which("jq"), "Linux jq required")
class ExecutableReview(unittest.TestCase):
    def review(self, blockers, ready=True, method="install-erase", filesystem="ext4"):
        request = dict(locale="en_US.UTF-8", timezone="UTC", keyboard="us", offline=True, selectedDrivers=[], filesystem=filesystem)
        info = dict(executorAvailable=ready, timezones=["UTC"], graphics=[], drivers={"choices":[]})
        result = subprocess.run(["jq", "--argjson", "request", json.dumps(request), "--argjson", "info", json.dumps(info), "-f", str(ROOT / "scripts/installer-review.jq")], input=json.dumps(dict(kind=method, blockers=blockers)), text=True, capture_output=True, check=True)
        return json.loads(result.stdout)

    def test_only_matched_whole_disk_ext4_is_executable(self):
        self.assertTrue(self.review([])["canExecute"])
        self.assertFalse(self.review([], ready=False)["canExecute"])
        self.assertFalse(self.review([], method="install-alongside")["canExecute"])
        self.assertFalse(self.review([], filesystem="btrfs")["canExecute"])

    def test_protected_mounted_and_stale_blockers_never_disappear(self):
        for blocker in ["Protected disk", "Mounted disk", "Inventory changed", "Unknown executor"]:
            with self.subTest(blocker=blocker):
                for blockers in [[blocker], [blocker, PREVIEW], [PREVIEW, blocker]]:
                    result = self.review(blockers)
                    self.assertFalse(result["canExecute"])
                    self.assertIn(blocker, result["blockers"])
