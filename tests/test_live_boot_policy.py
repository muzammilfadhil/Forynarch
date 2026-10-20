import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("live_boot_policy", ROOT / "scripts/live_boot_policy.py")
policy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(policy)


class LiveBootPolicy(unittest.TestCase):
    def profile(self, root):
        (root / "profiledef.sh").write_text("# fixture\n")
        for folder in ("grub", "efiboot/loader/entries", "syslinux"):
            (root / folder).mkdir(parents=True)

    def test_local_entries_disable_automatic_copy_but_pxe_and_explicit_choices_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.profile(root)
            files = {
                "grub/grub.cfg": 'menuentry "Local" {\n linux /arch/vmlinuz archisobasedir=arch\n}\n',
                "grub/loopback.cfg": 'linux /arch/vmlinuz archisobasedir=arch img_loop="${iso_path}"\n',
                "efiboot/loader/entries/01.conf": "options archisobasedir=arch quiet\n",
                "syslinux/archiso_sys.cfg": "APPEND archisobasedir=arch copytoram=y\nAPPEND archisobasedir=arch copytoram=n\n",
                "syslinux/archiso_pxe.cfg": "APPEND archisobasedir=arch archiso_http_srv=http://example.test\n",
            }
            for name, text in files.items(): (root / name).write_text(text)
            self.assertEqual(policy.apply(root), (5, 3))
            self.assertIn("copytoram=n", (root / "grub/loopback.cfg").read_text())
            self.assertEqual((root / "syslinux/archiso_pxe.cfg").read_text(), files["syslinux/archiso_pxe.cfg"])
            self.assertEqual((root / "syslinux/archiso_sys.cfg").read_text(), files["syslinux/archiso_sys.cfg"])
            self.assertEqual(policy.apply(root), (5, 0))

    def test_unknown_profile_fails_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.profile(root)
            path = root / "grub/grub.cfg"; path.write_text("linux /unrelated/kernel\n")
            with self.assertRaises(ValueError): policy.apply(root)
            self.assertEqual(path.read_text(), "linux /unrelated/kernel\n")
