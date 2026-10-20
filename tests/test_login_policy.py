import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name != "nt" and shutil.which("bash"), "Requires native Bash")
class LoginPolicy(unittest.TestCase):
    def test_live_to_target_removes_autologin_and_tty_bootstrap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for home in ("etc/skel", "root", "home/liveuser"):
                (root / home).mkdir(parents=True)
                (root / home / ".bash_profile").write_text("dbus-run-session start-hyprland\n")
            old = root / "etc/systemd/system/getty@tty1.service.d/autologin.conf"
            old.parent.mkdir(parents=True)
            old.write_text("ExecStart=agetty --autologin liveuser\n")
            for mode in ("live", "target"):
                result = subprocess.run(["bash", str(ROOT / "scripts/configure-login.sh"), str(root), mode], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(old.exists())
                self.assertEqual(os.readlink(root / "etc/systemd/system/default.target"), "/usr/lib/systemd/system/graphical.target")
                self.assertEqual(os.readlink(root / "etc/systemd/system/display-manager.service"), "/usr/lib/systemd/system/sddm.service")
                for home in ("etc/skel", "root", "home/liveuser"):
                    self.assertNotIn("start-hyprland", (root / home / ".bash_profile").read_text())
                live_config = root / "etc/sddm.conf.d/20-forynarch-live.conf"
                prepare = root / "etc/systemd/system/sddm.service.d/20-forynarch-live.conf"
                if mode == "live":
                    self.assertIn("User=liveuser", live_config.read_text())
                    self.assertIn("Relogin=false", live_config.read_text())
                    self.assertIn("Requires=forynarch-live-prepare.service", prepare.read_text())
                else:
                    self.assertFalse(live_config.exists())
                    self.assertFalse(prepare.exists())

    def test_rejects_host_root(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/configure-login.sh"), "/", "live"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_staging_helpers_reject_symlink_to_host_root(self):
        with tempfile.TemporaryDirectory() as directory:
            alias = Path(directory) / "host-root"
            alias.symlink_to("/", target_is_directory=True)
            for script, arguments in (("configure-login.sh", ["live"]), ("configure-boot.sh", []), ("configure-branding.sh", [])):
                with self.subTest(script=script):
                    result = subprocess.run(["bash", str(ROOT / "scripts" / script), str(alias), *arguments], capture_output=True)
                    self.assertEqual(result.returncode, 2)
