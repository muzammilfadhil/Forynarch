import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == "nt", "Linux staging and executable permissions")
class NativeWindowControls(unittest.TestCase):
    def stage(self, root, package_result, expected="", titlebars=False, mode="live", database=False):
        destination = root / "target"
        (destination / "etc").mkdir(parents=True, exist_ok=True)
        controls = root / "controls"
        controls.mkdir(exist_ok=True)
        (controls / "forynarch-window-controls.so").write_bytes(b"fixture extension")
        (controls / "hyprland-version.txt").write_text("hyprland 0.56.2-4\n")
        if database:
            (destination / "var/lib/pacman/local").mkdir(parents=True)
        if titlebars:
            (controls / "hyprbars.so").write_bytes(b"fixture titlebars")
            (controls / "LICENSE").write_text("fixture license")
            (controls / "upstream-commit.txt").write_text("fixture revision")
        commands = root / "bin"
        commands.mkdir(exist_ok=True)
        package = commands / "pacman"
        package.write_text("#!/bin/sh\n" + package_result + "\n")
        package.chmod(0o755)
        env = dict(os.environ, PATH=str(commands)+":"+os.environ["PATH"],
                   FORYNARCH_WINDOW_CONTROLS_DIR=str(controls),
                   FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION=expected)
        if titlebars:
            env['FORYNARCH_TITLEBARS_DIR'] = str(controls)
        result = subprocess.run(["bash", str(ROOT / "scripts/integrate-desktop.sh"), str(destination), mode],
                                env=env, capture_output=True, text=True)
        return result, destination

    def test_titlebars_accept_matching_version_before_live_database_exists(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, destination = self.stage(Path(temporary), 'exit 1', 'hyprland 0.56.2-4', titlebars=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((destination / 'usr/lib/forynarch/hyprbars.so').read_bytes(), b'fixture titlebars')

    def test_titlebars_reject_actual_version_mismatch(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, destination = self.stage(Path(temporary), "echo 'hyprland 9.9-1'", 'hyprland 0.56.2-4', titlebars=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((destination / 'usr/lib/forynarch/hyprbars.so').exists())

    def test_titlebars_do_not_use_template_version_for_target_or_populated_live(self):
        for mode, database in [('target', False), ('live', True)]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                result, destination = self.stage(Path(temporary), 'exit 1', 'hyprland 0.56.2-4', titlebars=True, mode=mode, database=database)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((destination / 'usr/lib/forynarch/hyprbars.so').exists())

    def test_template_requires_matching_explicit_package_version(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result, destination = self.stage(root, "exit 1")
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((destination / "usr/lib/forynarch/forynarch-window-controls.so").exists())
            result, destination = self.stage(root, "exit 1", "hyprland 0.56.2-4")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((destination / "usr/lib/forynarch/forynarch-window-controls.so").read_bytes(), b"fixture extension")

    def test_installed_package_mismatch_cannot_be_overridden_by_template_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, destination = self.stage(Path(temporary), "echo 'hyprland 9.9-1'", "hyprland 0.56.2-4")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Rebuild native window controls", result.stderr)
            self.assertFalse((destination / "usr/lib/forynarch/forynarch-window-controls.so").exists())


if __name__ == "__main__":
    unittest.main()
