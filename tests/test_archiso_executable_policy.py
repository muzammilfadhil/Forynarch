"""Prevent Live helpers losing their execute bits inside a built ISO."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("executable_policy",ROOT/"scripts/archiso_executable_policy.py")
policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)


@unittest.skipUnless(os.name=="posix","requires Linux file modes")
class ExecutablePolicy(unittest.TestCase):
    def test_boot_helper_and_privileged_executor_keep_executable_modes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            definition=root/"profiledef.sh";definition.write_text("declare -A file_permissions=()\n")
            for directory,name in [("bin","forynarch-desktop-integrate"),("libexec","forynarch-install-system")]:
                parent=root/"airootfs/usr/local"/directory;parent.mkdir(parents=True)
                helper=parent/name;helper.write_text("fixture");helper.chmod(0o755)
                inert=parent/"resource.json";inert.write_text("{}");inert.chmod(0o644)
            self.assertEqual(policy.apply(root),2)
            first=definition.read_text()
            self.assertIn('["/usr/local/bin/forynarch-desktop-integrate"]="0:0:755"',first)
            self.assertIn('["/usr/local/libexec/forynarch-install-system"]="0:0:755"',first)
            self.assertNotIn("resource.json",first)
            self.assertEqual(policy.apply(root),2)
            self.assertEqual(first,definition.read_text())
