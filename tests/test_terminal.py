import importlib.util
import os
from pathlib import Path
import tempfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("terminal_helper", Path(__file__).resolve().parents[1] / "scripts/forynarch-terminal.py")
terminal = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(terminal)


class PointedTerminal(unittest.TestCase):
    def test_hidden_workspace_and_occluded_terminal_are_not_pointed(self):
        foot = dict(address="alacritty", at=[10, 10], size=[100, 100], workspace={"id": 1}, **{"class": "alacritty"}, focusHistoryID=3)
        cover = dict(foot, address="files", **{"class": "thunar"}, floating=True, focusHistoryID=0)
        hidden = dict(foot, address="hidden", workspace={"id": 2}, floating=True, focusHistoryID=-1)
        result = terminal.pointed_client([foot, cover, hidden], [{"activeWorkspace": {"id": 1}}], {"x": 40, "y": 40})
        self.assertEqual(result["address"], "files")
        self.assertFalse(terminal.terminal(result))

    def test_recent_floating_window_and_exclusive_edges(self):
        old = dict(at=[0, 0], size=[100, 100], workspace={"id": 1}, floating=True, focusHistoryID=4)
        new = dict(old, focusHistoryID=0)
        monitors = [{"activeWorkspace": {"id": 1}}]
        self.assertIs(terminal.pointed_client([old, new], monitors, {"x": 50, "y": 50}), new)
        self.assertEqual(terminal.pointed_client([new], monitors, {"x": 100, "y": 50}), {})


@unittest.skipIf(os.name == "nt", "Requires native Unix process ownership and symlinks")
class ShellDirectory(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.proc = self.root / "proc"
        self.home = self.root / "home"
        self.project = self.home / "project with spaces"
        self.project.mkdir(parents=True)
        self.make_process(10, 1, "alacritty", 0, 0, 0, [20], self.home)
        self.make_process(20, 10, "bash", 1, 20, 20, [], self.project)

    def make_process(self, pid, ppid, name, tty, pgrp, foreground, children, cwd):
        directory = self.proc / str(pid)
        (directory / "task" / str(pid)).mkdir(parents=True, exist_ok=True)
        executable = self.root / "bin" / name
        executable.parent.mkdir(exist_ok=True)
        executable.touch()
        fields = ["S", str(ppid), str(pgrp), "20", str(tty), str(foreground)] + ["0"] * 13 + ["12345"]
        (directory / "stat").write_text(str(pid) + " (process name) " + " ".join(fields))
        (directory / "task" / str(pid) / "children").write_text(" ".join(map(str, children)))
        for key, target in (("exe", executable), ("cwd", cwd)):
            link = directory / key
            link.unlink(missing_ok=True)
            link.symlink_to(target)

    def test_shell_cd_inherited_instead_of_terminal_startup_directory(self):
        self.assertEqual(terminal.shell_directory(10, self.proc), self.project)
        changed = self.project / "after cd"
        changed.mkdir()
        link = self.proc / "20/cwd"
        link.unlink()
        link.symlink_to(changed)
        self.assertEqual(terminal.shell_directory(10, self.proc), changed)

    def test_foreground_nested_shell_wins_over_background_shell(self):
        self.make_process(20, 10, "bash", 1, 20, 30, [30, 40], self.home)
        self.make_process(30, 20, "zsh", 1, 30, 30, [], self.project)
        self.make_process(40, 20, "bash", 1, 40, 30, [], self.home)
        self.assertEqual(terminal.shell_directory(10, self.proc), self.project)

    def test_foreground_editor_uses_parent_shell_directory(self):
        self.make_process(20, 10, "bash", 1, 20, 30, [30], self.project)
        self.make_process(30, 20, "vim", 1, 30, 30, [], self.home)
        self.assertEqual(terminal.shell_directory(10, self.proc), self.project)

    def test_foreign_process_missing_pid_and_multiple_terminals_fall_back(self):
        self.assertIsNone(terminal.shell_directory(10, self.proc, os.getuid() + 1))
        self.assertIsNone(terminal.shell_directory(99999, self.proc))
        self.make_process(10, 1, "alacritty", 0, 0, 0, [20, 30], self.home)
        self.make_process(30, 10, "bash", 2, 30, 30, [], self.home)
        self.assertIsNone(terminal.shell_directory(10, self.proc))

    def test_deleted_working_directory_falls_back(self):
        self.project.rmdir()
        self.assertIsNone(terminal.shell_directory(10, self.proc))

    def test_compositor_controlling_tty_is_not_a_second_shell_session(self):
        self.make_process(10, 1, "alacritty", 99, 10, 10, [20], self.home)
        self.assertEqual(terminal.shell_directory(10, self.proc), self.project)


class LaunchTerminal(unittest.TestCase):
    def test_missing_compositor_uses_home_as_one_argument(self):
        with patch.object(terminal, "query", side_effect=OSError), patch.object(terminal.os, "execvp") as execute:
            with patch("forynarch_defaults.terminal_command", return_value=["alacritty", "--working-directory", str(Path.home())]):
                terminal.main([])
        execute.assert_called_once_with("alacritty", ["alacritty", "--working-directory", str(Path.home())])
