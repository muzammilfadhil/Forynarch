import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("production_planner", ROOT / "scripts/package_plan.py")
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)


class ApplicationSelection(unittest.TestCase):
    def setUp(self):
        self.catalog = planner.load_catalog(ROOT / "packages/optional-catalog.yaml")

    def test_empty_selection_has_no_browser_or_flatpak(self):
        plan = planner.create_plan(self.catalog)
        self.assertEqual(plan["explicit_optional_packages"], [])
        self.assertEqual(plan["selected_flatpaks"], [])
        core = (ROOT / "packages/target-core.proposed.txt").read_text().splitlines()
        for package in ("firefox", "chromium", "vivaldi", "flatpak", "filezilla", "openssh", "tigervnc"):
            self.assertNotIn(package, core)

    def test_explicit_external_browsers_require_only_their_runtime(self):
        plan = planner.create_plan(self.catalog, ["google-chrome", "zen"])
        self.assertEqual(plan["explicit_optional_packages"], ["flatpak"])
        self.assertEqual(plan["selected_flatpaks"], ["app.zen_browser.zen", "com.google.Chrome"])

    def test_unreviewed_external_app_or_command_is_rejected(self):
        group = next(g for g in self.catalog["groups"] if g["id"] == "zen")
        group["flatpaks"] = ["unreviewed.App"]
        with self.assertRaises(planner.PlanError):
            planner.validate_catalog(self.catalog)


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"), "requires Linux shell")
class DesktopIntegration(unittest.TestCase):
    def test_branding_preserves_actions_and_hides_only_requested_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            applications = root / "usr/share/applications"
            applications.mkdir(parents=True)
            plugin = root / "usr/lib/thunarx-3/thunar-wallpaper-plugin.so"
            plugin.parent.mkdir(parents=True)
            plugin.write_bytes(b"upstream XFCE module")
            (applications / "thunar.desktop").write_text(
                "[Desktop Entry]\nName=Thunar\nName[de]=Thunar\nExec=thunar %U\n"
                "[Desktop Action new-window]\nName=New Window\nExec=thunar\n")
            (applications / "thunar-settings.desktop").write_text("[Desktop Entry]\nName=File Manager Settings\nIcon=Thunar\n")
            (applications / "thunar-bulk-rename.desktop").write_text("[Desktop Entry]\nName=Bulk Rename\nExec=thunar -B %F\nIcon=Thunar\n")
            for name in ("xfce4-about", "avahi-discover", "bssh", "bvnc", "unrelated"):
                (applications / (name + ".desktop")).write_text("[Desktop Entry]\nName=Original\n")
            result = subprocess.run(["bash", str(ROOT / "scripts/forynarch-desktop-integrate.sh"), directory], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(plugin.exists())
            self.assertEqual(plugin.with_suffix(".so.disabled").read_bytes(), b"upstream XFCE module")
            destination = root / "usr/local/share/applications"
            branded = (destination / "thunar.desktop").read_text()
            self.assertIn("Name=File Manager\n", branded)
            self.assertIn("Name=New Window", branded)
            self.assertNotIn("Name[de]", branded)
            self.assertIn("Exec=forynarch-file-manager %U", branded)
            self.assertIn("Icon=system-file-manager", branded)
            self.assertIn("Icon=preferences-desktop", (destination / "thunar-settings.desktop").read_text())
            renamed = (destination / "thunar-bulk-rename.desktop").read_text()
            self.assertIn("Icon=edit-rename", renamed)
            self.assertIn("Exec=thunar -B %F", renamed)
            self.assertFalse((destination / "unrelated.desktop").exists())
            for name in ("xfce4-about", "avahi-discover", "bssh", "bvnc"):
                self.assertIn("Hidden=true", (destination / (name + ".desktop")).read_text())

    def test_live_authorization_does_not_enter_target(self):
        for mode in ("target", "live"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "etc").mkdir()
                result = subprocess.run(["bash", str(ROOT / "scripts/integrate-desktop.sh"), directory, mode], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / "etc/polkit-1/rules.d/49-forynarch-apps.rules").exists(), mode == "live")
                self.assertTrue((root / "etc/systemd/system/sddm.service.d/10-forynarch.conf").exists())
                self.assertEqual((root / "etc/sddm.conf.d/20-forynarch-live.conf").exists(), mode == "live")
                self.assertEqual((root / "usr/local/bin/forynarch-apps").exists(), mode == "live")
                self.assertFalse((root / "usr/share/applications/forynarch-apps.desktop").exists())
                self.assertEqual(os.readlink(root / "etc/systemd/system/avahi-daemon.service"), "/dev/null")
                self.assertEqual(os.readlink(root / "etc/systemd/system/sshd.service"), "/dev/null")
                self.assertEqual(os.readlink(root / "etc/systemd/system-generators/systemd-ssh-generator"), "/dev/null")
                self.assertEqual(os.readlink(root / "etc/systemd/system/systemd-networkd.service"), "/dev/null")
                self.assertEqual(json.loads((root / "usr/share/forynarch/optional-catalog.json").read_text())["policy"]["user_must_opt_in"], True)


if __name__ == "__main__":
    unittest.main()
