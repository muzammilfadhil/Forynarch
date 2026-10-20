import importlib.util
import tarfile
import tempfile
import unittest
import os
import shutil
import subprocess
import copy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("automation_support", ROOT / "scripts/automation_support.py")
support = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(support)


def member(name, kind=tarfile.REGTYPE, link=""):
    item = tarfile.TarInfo(name)
    item.type = kind
    item.linkname = link
    return item


class ArchiveContract(unittest.TestCase):
    def test_regular_tree_and_system_symlink_allowed(self):
        support.validate_members([member(".", tarfile.DIRTYPE), member("./usr", tarfile.DIRTYPE),
                                  member("./usr/file"), member("./bin", tarfile.SYMTYPE, "usr/bin")])

    def test_absolute_or_traversal_member_rejected(self):
        for path in ("/etc/shadow", "../secret", "./etc/../../secret"):
            with self.subTest(path=path), self.assertRaises(support.AutomationError):
                support.validate_members([member(path)])

    def test_symlink_ancestor_rejected_regardless_of_order(self):
        entries = [member("./escape", tarfile.SYMTYPE, "/etc"), member("./escape/shadow")]
        for order in (entries, entries[::-1]):
            with self.assertRaises(support.AutomationError):
                support.validate_members(order)

    def test_devices_and_fifo_rejected(self):
        for kind in (tarfile.CHRTYPE, tarfile.BLKTYPE, tarfile.FIFOTYPE):
            with self.subTest(kind=kind), self.assertRaises(support.AutomationError):
                support.validate_members([member("./special", kind)])

    def test_duplicate_path_rejected(self):
        with self.assertRaises(support.AutomationError):
            support.validate_members([member("./file"), member("file")])

    def test_hardlink_targets_must_exist_and_not_escape(self):
        support.validate_members([member("./a"), member("./b", tarfile.LNKTYPE, "./a")])
        for target in ("../secret", "/etc/shadow", "missing"):
            with self.subTest(target=target), self.assertRaises(support.AutomationError):
                support.validate_members([member("./b", tarfile.LNKTYPE, target)])


class PackageManifestContract(unittest.TestCase):
    def read(self, content):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "packages.txt"
            path.write_text(content, encoding="utf-8")
            return support.read_package_list(path)

    def test_comments_and_blank_lines(self):
        self.assertEqual(self.read("# review\n\nbase\nlinux # kernel\n"), ["base", "linux"])

    def test_empty_duplicate_and_shell_input_rejected(self):
        for content in ("# nothing\n", "base\nbase\n", "base; id\n", "--root\n", "../base\n"):
            with self.subTest(content=content), self.assertRaises(support.AutomationError):
                self.read(content)

    def test_proposed_core_has_no_explicit_developer_packages(self):
        packages = support.read_package_list(ROOT / "packages/target-core.proposed.txt")
        self.assertTrue({"base", "linux", "hyprland", "sudo"}.issubset(packages))
        self.assertFalse(set(packages) & {"git", "nodejs", "npm", "python", "base-devel", "docker", "code"})


class InstalledExampleAdapterContract(unittest.TestCase):
    # Structural fixture only; this does not assert Hyprland runtime behavior.
    example = '''local terminal = "kitty"
local fileManager = "dolphin"
local menu = "hyprlauncher"
-- hl.on("hyprland.start", function ()
-- hl.exec_cmd(terminal)
-- hl.exec_cmd("nm-applet")
-- hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    gaps_in = 5,
    gaps_out = 20,
    border_size = 2,
    rounding = 10,
shadow = { enabled = true }
blur = { enabled = true }
animations = { enabled = true }
'''

    def test_version_checked_adaptation(self):
        text = support.adapt_installed_example(self.example, "0.56.2-4")
        self.assertIn('local terminal = "forynarch-terminal"', text)
        self.assertIn('local menu = "forynarch-launcher"', text)
        self.assertIn('local fileManager = "forynarch-files"', text)
        self.assertIn('" + SPACE"', text)
        self.assertIn('hl.exec_cmd("forynarch-session-start")', text)
        self.assertNotIn("firefox", text)
        self.assertNotIn("enabled = true", text)

    def test_packaged_branding_alignment_does_not_preserve_upstream_logo(self):
        source = self.example + '\nhl.config({misc = {\n    disable_hyprland_logo   = false,\n    force_default_wallpaper = -1,\n}})\n'
        text = support.adapt_installed_example(source, "0.56.2-4")
        self.assertIn('disable_hyprland_logo   = true,', text)
        self.assertIn('force_default_wallpaper = 0,', text)
        self.assertIn('"identity.lua"', text)

    def test_unknown_release_rejected(self):
        for version in ("0.57.0-1", "0.54.0-1", "git", ""):
            with self.subTest(version=version), self.assertRaises(support.AutomationError):
                support.adapt_installed_example(self.example, version)

    def test_changed_or_missing_example_shape_rejected(self):
        for source in ("", self.example.replace("local terminal", "terminal"),
                       self.example.replace("-- end)", "-- no end"),
                       self.example.replace('" + R"', '" + X"')):
            with self.subTest(source=source), self.assertRaises(support.AutomationError):
                support.adapt_installed_example(source, "0.56.2-4")


class InventoryContract(unittest.TestCase):
    def test_core_plus_dependencies_and_upgrade(self):
        support.verify_inventory(["base 1", "lib 1"], ["git 2 100", "lib 2 50"],
                                 ["git 2", "base 1", "lib 2"])

    def test_empty_selection_requires_exact_core(self):
        support.verify_inventory(["base 1"], [], ["base 1"])
        for actual in (["base 1", "git 2"], [], ["base 2"]):
            with self.subTest(actual=actual), self.assertRaises(support.AutomationError):
                support.verify_inventory(["base 1"], [], actual)

    def test_duplicate_and_malformed_entries_rejected(self):
        for actual in (["base 1", "base 1"], ["base 1 unexpected"]):
            with self.subTest(actual=actual), self.assertRaises(support.AutomationError):
                support.verify_inventory(["base 1"], [], actual)


class PartitionTableContract(unittest.TestCase):
    def setUp(self):
        self.table = {"partitiontable": {"device": "/dev/vda", "label": "gpt", "partitions": [
            {"node": "/dev/vda1", "type": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"},
            {"node": "/dev/vda2", "type": "0fc63daf-8483-4772-8e79-3d69d8477de4"}]}}

    def test_expected_disk_and_partition_types(self):
        self.assertEqual(support.partition_nodes(self.table, "/dev/vda"), ["/dev/vda1", "/dev/vda2"])

    def test_wrong_parent_type_count_and_label_rejected(self):
        mutations = [lambda t: t["partitiontable"].update(device="/dev/sda"),
                     lambda t: t["partitiontable"].update(label="dos"),
                     lambda t: t["partitiontable"]["partitions"].pop(),
                     lambda t: t["partitiontable"]["partitions"][0].update(node="/dev/sda1"),
                     lambda t: t["partitiontable"]["partitions"][0].update(type="other")]
        for mutate in mutations:
            table = copy.deepcopy(self.table)
            mutate(table)
            with self.assertRaises(support.AutomationError):
                support.partition_nodes(table, "/dev/vda")

    def test_malformed_table_rejected(self):
        for table in ({}, {"partitiontable": None}):
            with self.assertRaises(support.AutomationError):
                support.partition_nodes(table, "/dev/vda")

class NonPrivilegedCLIContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bash = shutil.which("bash")
        if not cls.bash and os.name == "nt":
            candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
            if candidate.is_file():
                cls.bash = str(candidate)
        if not cls.bash:
            raise unittest.SkipTest("Bash unavailable")

    def run_script(self, script, *args):
        return subprocess.run([self.bash, "scripts/" + script, *args], cwd=ROOT,
                              capture_output=True, text=True, check=False)

    def test_builder_plan_is_nonprivileged(self):
        result = self.run_script("forynarch.sh", "plan")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("independent core rootfs", result.stdout)

    def test_unknown_builder_option_rejected(self):
        result = self.run_script("forynarch.sh", "build", "--erase-everything")
        self.assertEqual(result.returncode, 2)

    def test_unknown_desktop_shell_rejected_before_privileged_operations(self):
        result = self.run_script("forynarch.sh", "build", "--desktop-shell", "unreviewed")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown desktop shell", result.stderr)

    def test_installer_help_needs_no_device_or_root(self):
        result = self.run_script("install-target.sh", "--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Review is the default", result.stdout)

    def test_unapproved_bootstrap_cannot_mutate_artifacts(self):
        before = {str(p) for directory in (ROOT / "work", ROOT / "out") for p in directory.rglob("*")}
        result = self.run_script("forynarch.sh", "bootstrap")
        self.assertNotEqual(result.returncode, 0)
        after = {str(p) for directory in (ROOT / "work", ROOT / "out") for p in directory.rglob("*")}
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
