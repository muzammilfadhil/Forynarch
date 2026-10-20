from pathlib import Path
import shutil
import subprocess
import unittest

class AutoSnap(unittest.TestCase):
    def test_pointer_passthrough_drag_geometry_and_idle_lifecycle(self):
        executable = shutil.which("lua")
        if not executable: self.skipTest("Native Lua interpreter required")
        root = Path(__file__).resolve().parents[1]
        result = subprocess.run([executable, str(root / "tests/fixtures/auto-snap.lua"), str(root / "config/hypr/auto-snap.lua")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("AUTO_SNAP_INPUT_AND_GEOMETRY_OK", result.stdout)
