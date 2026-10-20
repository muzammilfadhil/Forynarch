import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == "nt", "Requires native Bash staging")
class BrandingReplacement(unittest.TestCase):
    def test_replacement_updates_all_consumers_and_does_not_touch_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            staged = Path(directory) / "target"
            (source / "scripts").mkdir(parents=True)
            (source / "assets/branding").mkdir(parents=True)
            (source / "config").mkdir()
            shutil.copyfile(ROOT / "config/os-release", source / "config/os-release")
            (staged / "etc").mkdir(parents=True)
            (staged / "usr/lib").mkdir(parents=True)
            upstream = staged / "usr/lib/os-release"
            upstream.write_text('NAME="Arch Linux"\nLOGO=archlinux-logo\nIMAGE_ID=forynarch\nIMAGE_VERSION=test\n')
            (staged / "etc/os-release").symlink_to('../usr/lib/os-release')
            (staged / "etc/pacman.conf").write_text('[options]\nNoUpgrade = existing-file\n')
            script = source / "scripts/configure-branding.sh"
            shutil.copyfile(ROOT / "scripts/configure-branding.sh", script)
            asset = source / "assets/branding/logo.svg"
            for fill in ("navy", "blue"):
                content = f'<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" fill="{fill}"/></svg>'
                asset.write_text(content)
                result = subprocess.run(["bash", str(script), str(staged)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                copies = list(staged.rglob("*.svg"))
                self.assertEqual(len(copies), 5)
                for copy in copies:
                    self.assertEqual(copy.read_text(), content)
                self.assertEqual(asset.read_text(), content)
                release = staged / "etc/os-release"
                self.assertFalse(release.is_symlink())
                self.assertIn('LOGO=forynarch\n', release.read_text())
                self.assertIn('IMAGE_VERSION=test\n', release.read_text())
                self.assertIn('LOGO=archlinux-logo\n', upstream.read_text())
                pacman = (staged / "etc/pacman.conf").read_text()
                self.assertEqual(pacman.count('NoUpgrade = etc/os-release'), 1)
                self.assertIn('NoUpgrade = existing-file', pacman)
