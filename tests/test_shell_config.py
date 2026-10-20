import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipIf(os.name == "nt", "Requires native staging permissions and Zsh")
class ShellConfiguration(unittest.TestCase):
    def test_seed_preserves_user_configuration_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            staged = Path(temporary)
            (staged / "etc/skel").mkdir(parents=True)
            (staged / "root").mkdir()
            custom = staged / "root/.zshrc"
            custom.write_text("# Personal settings\n")
            for _ in range(2):
                subprocess.run(["bash", str(ROOT / "scripts/configure-terminal.sh"), str(staged)], check=True)
            self.assertEqual(custom.read_text(), "# Personal settings\n")
            self.assertIn("init.zsh", (staged / "etc/skel/.zshrc").read_text())
            self.assertTrue((staged / "etc/skel/.config/alacritty/alacritty.toml").is_file())
            self.assertTrue((staged / "usr/share/forynarch/fastfetch.jsonc").is_file())

    def test_noninteractive_shell_has_no_output_or_created_state(self):
        executable = shutil.which("zsh")
        if not executable: self.skipTest("Native Zsh required")
        with tempfile.TemporaryDirectory() as temporary:
            environment = dict(os.environ, HOME=temporary, XDG_CONFIG_HOME=temporary + "/config", XDG_STATE_HOME=temporary + "/state")
            result = subprocess.run([executable, "-f", "-c", 'source "$1"; print -r -- ready',
                "test", str(ROOT / "config/zsh/init.zsh")], env=environment, capture_output=True, text=True)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "ready\n", ""))
            self.assertFalse((Path(temporary) / "state").exists())
