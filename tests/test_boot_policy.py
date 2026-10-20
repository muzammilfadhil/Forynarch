import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("boot_policy", ROOT / "scripts/boot_policy.py")
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class BootPolicy(unittest.TestCase):
    def test_both_initramfs_families_and_idempotence(self):
        for value in ("base udev kms archiso block filesystems", "base systemd kms keyboard block filesystems"):
            source = f"# HOOKS=(example)\nHOOKS=({value})\n"
            result = policy.hooks(source)
            self.assertIn("kms plymouth", result)
            self.assertEqual(result, policy.hooks(result))
            self.assertTrue(result.startswith("# HOOKS=(example)"))

    def test_unreviewed_hooks_are_rejected(self):
        with self.assertRaises(ValueError):
            policy.hooks("HOOKS=(base custom filesystems)\n")

    def test_boot_parameters_keep_medium_policy_and_accessibility(self):
        normal = "options archisobasedir=arch copytoram=n\n"
        result = policy.parameters(normal)
        self.assertIn("copytoram=n", result)
        self.assertIn(" splash ", result)
        self.assertEqual(result, policy.parameters(result))
        accessible = "options archisobasedir=arch accessibility=on\n"
        self.assertEqual(accessible, policy.parameters(accessible))

    def test_target_install_hook_template_is_updated(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "etc").mkdir()
            template = root / "usr/share/forynarch/mkinitcpio.conf.install"
            template.parent.mkdir(parents=True)
            template.write_text("HOOKS=(base systemd kms filesystems)\n")
            policy.apply_root(root)
            self.assertIn("kms plymouth", template.read_text())
        with self.assertRaises(ValueError):
            policy.apply_root(Path("/"))
