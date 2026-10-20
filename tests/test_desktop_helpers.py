"""Safety and idle-work contracts; these do not replace compositor tests."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DesktopHelperContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bash = shutil.which("bash")
        if os.name == "nt":
            candidate = Path("C:/Program Files/Git/bin/bash.exe")
            if candidate.exists():
                cls.bash = str(candidate)
        if not cls.bash:
            raise unittest.SkipTest("Bash unavailable")

    def invoke(self, directory, script, *args):
        return subprocess.run(
            [self.bash, "-c", 'export PATH="$PWD/bin:$PATH"; '
             'export XDG_RUNTIME_DIR="$PWD/runtime"; export XDG_CONFIG_HOME="$PWD/config"; exec bash "$@"',
             "desktop-test", (ROOT / "scripts" / script).as_posix(), *args],
            cwd=directory, capture_output=True, text=True, check=False)

    def sandbox(self, directory):
        (directory / "runtime").mkdir()
        (directory / "bin").mkdir()
        for name in ("hyprctl", "systemctl", "hyprlock"):
            stub = directory / "bin" / name
            stub.write_text('#!/usr/bin/env bash\necho called >> "$PWD/actions"\nexit 99\n', newline="\n")
            stub.chmod(0o755)

    def test_status_uses_cache_without_compositor_or_power_call(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            (directory / "runtime" / "forynarch-active-workspace").write_bytes(b"3\n")
            result = self.invoke(directory, "forynarch-workspace.sh", "status", "3")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["class"], "active")
            self.assertFalse((directory / "actions").exists())

    def test_workspace_rejects_non_slot_input_without_calling_compositor(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            for slot in ("0", "6", "1; touch actions", '1\"})', ""):
                with self.subTest(slot=slot):
                    result = self.invoke(directory, "forynarch-workspace.sh", "focus", slot)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((directory / "actions").exists())

    def test_launcher_uses_ready_shell_without_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            for name, script in (("qs", 'echo shell >> "$PWD/actions"'),
                                 ("fuzzel", 'echo fallback >> "$PWD/actions"')):
                stub = directory / "bin" / name
                stub.write_text('#!/usr/bin/env bash\n' + script + '\n', newline="\n")
                stub.chmod(0o755)
            result = self.invoke(directory, "forynarch-launcher.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((directory / "actions").read_text().strip(), "shell")

    def test_launcher_falls_back_when_shell_ipc_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            for name, script in (("qs", 'exit 1'),
                                 ("fuzzel", 'echo fallback >> "$PWD/actions"')):
                stub = directory / "bin" / name
                stub.write_text('#!/usr/bin/env bash\n' + script + '\n', newline="\n")
                stub.chmod(0o755)
            result = self.invoke(directory, "forynarch-launcher.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((directory / "actions").read_text().strip(), "fallback")

    def test_native_glass_rejects_invalid_input_without_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            for args in (("on", "101"), ("on", "84;touch-bad"), ("unknown", "84")):
                result = self.invoke(directory, "forynarch-application-theme.sh", *args)
                self.assertEqual(result.returncode, 2)
                self.assertFalse((directory / "config").exists())

    def test_native_glass_roundtrip_preserves_terminal_settings(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            terminal = directory / "config/alacritty/alacritty.toml"
            terminal.parent.mkdir(parents=True)
            terminal.write_text('[window]\nopacity = 0.5\n[font]\nsize = 12\n[colors.primary]\nbackground = "#123456"\n', newline="\n")
            result = self.invoke(directory, "forynarch-application-theme.sh", "on", "76")
            self.assertEqual(result.returncode, 0, result.stderr)
            palette = directory / "config/gtk-3.0/forynarch-glass.css"
            self.assertIn("rgba(17,24,35,0.76)", palette.read_text())
            self.assertEqual(palette.read_text(), (directory / "config/gtk-4.0/forynarch-glass.css").read_text())
            self.assertIn("opacity = 0.76", terminal.read_text())
            before = palette.stat().st_mtime_ns
            self.assertEqual(self.invoke(directory, "forynarch-application-theme.sh", "on", "76").returncode, 0)
            self.assertEqual(before, palette.stat().st_mtime_ns)
            result = self.invoke(directory, "forynarch-application-theme.sh", "off", "76")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("rgba", palette.read_text())
            self.assertIn("opacity = 1.0", terminal.read_text())
            self.assertEqual(terminal.read_text().count("opacity ="), 1)
            self.assertIn("size = 12", terminal.read_text())
            self.assertIn('background = "#123456"', terminal.read_text())

    def test_cancel_sign_out_does_not_dispatch_or_change_power(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.sandbox(directory)
            picker = directory / "bin" / "fuzzel"
            picker.write_text('#!/usr/bin/env bash\n'
                              'if [[ ! -f "$PWD/asked" ]]; then\n'
                              '  touch "$PWD/asked"; echo "Sign out"\n'
                              'else echo Cancel; fi\n', newline="\n")
            picker.chmod(0o755)
            result = self.invoke(directory, "forynarch-power.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((directory / "asked").exists())
            self.assertFalse((directory / "actions").exists())


if __name__ == "__main__":
    unittest.main()
