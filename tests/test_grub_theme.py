import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('grub_theme',ROOT/'scripts/grub_theme.py')
theme=importlib.util.module_from_spec(spec);spec.loader.exec_module(theme)

class GrubTheme(unittest.TestCase):
    def test_staged_target_has_theme_license_and_diagnostic_generator(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'etc').mkdir()
            theme.apply_root(root)
            self.assertTrue((root/'usr/share/grub/themes/forynarch-particle/COPYING').is_file())
            self.assertIn('GRUB_THEME=',(root/'etc/default/grub').read_text())
            self.assertIn('grub-probe',(root/'etc/grub.d/41_forynarch_diagnostic').read_text())

    def test_live_profile_keeps_bios_and_boot_parameters_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'grub').mkdir()
            definition=root/'profiledef.sh';definition.write_text("bootmodes=('bios.syslinux' 'uefi.systemd-boot')\n")
            config=root/'grub/grub.cfg'
            config.write_text('timeout=15\nmenuentry "Arch Linux install medium" --class arch --id \'archlinux\' {\nlinux /%INSTALL_DIR%/vmlinuz-linux archisobasedir=arch copytoram=n\n}\n')
            theme.apply_profile(root);expected=config.read_text()
            theme.apply_profile(root)
            self.assertEqual(config.read_text(),expected)
            self.assertIn("'bios.syslinux' 'uefi.grub'",definition.read_text())
            self.assertIn('copytoram=n',expected)
            self.assertIn('set timeout=5',expected)
            self.assertIn('Try or install Forynarch',expected)

    def test_unknown_profile_is_rejected_before_replacing_boot_modes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);definition=root/'profiledef.sh';original="bootmodes=('unknown-boot')\n";definition.write_text(original)
            with self.assertRaises(ValueError):theme.apply_profile(root)
            self.assertEqual(definition.read_text(),original)

    def test_running_root_is_rejected(self):
        with self.assertRaises(ValueError):theme.apply_root(Path(Path.cwd().anchor))
