import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import forynarch_defaults as defaults

class DefaultApplications(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.env = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "user"), "XDG_DATA_DIRS": str(self.root / "system")})
        self.env.start(); self.addCleanup(self.env.stop)
        self.desktop("system", "Alacritty.desktop", "Alacritty", "")
        self.desktop("system", "kitty.desktop", "Kitty", "")
        self.desktop("system", "browser.desktop", "Browser", "x-scheme-handler/http;text/html;")
        self.executable = patch.object(defaults.shutil, "which", side_effect=lambda name: "/usr/bin/" + name)
        self.executable.start(); self.addCleanup(self.executable.stop)
        self.run = patch.object(defaults.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "browser.desktop\n"))
        self.process = self.run.start(); self.addCleanup(self.run.stop)

    def desktop(self, location, identity, name, mime, extra=""):
        path = self.root / location / "applications" / identity
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"[Desktop Entry]\nType=Application\nName={name}\nExec=example %u\nMimeType={mime}\n{extra}", encoding="utf-8")

    def test_choices_only_include_supporting_installed_apps(self):
        state = defaults.status()
        self.assertEqual(state["terminal"], "Alacritty.desktop")
        browser = next(row for row in state["rows"] if row["key"] == "browser")
        self.assertEqual([app["id"] for app in browser["choices"]], ["browser.desktop"])

    def test_hidden_user_override_masks_system_entry(self):
        self.desktop("user", "Alacritty.desktop", "Hidden", "", "Hidden=true\n")
        self.assertNotIn("Alacritty.desktop", defaults.applications())
        self.assertEqual(defaults.terminal_id(), "kitty.desktop")

    def test_terminal_choice_persists_without_replacing_unrelated_preferences(self):
        path = defaults.preferences(); path.parent.mkdir(parents=True)
        path.write_text('{"custom":true}')
        defaults.choose("terminal", "kitty.desktop")
        self.assertEqual(json.loads(path.read_text()), {"custom": True, "terminal": "kitty.desktop"})
        self.assertEqual(defaults.terminal_command(Path("/a b"), ["printf", "one;two"]),
                         ["kitty", "--directory", str(Path("/a b")), "printf", "one;two"])

    def test_removed_default_falls_back_and_rejects_unknown_application(self):
        defaults.choose("terminal", "kitty.desktop")
        (self.root / "system/applications/kitty.desktop").unlink()
        self.assertEqual(defaults.terminal_id(), "Alacritty.desktop")
        with self.assertRaises(ValueError): defaults.choose("terminal", "evil.desktop;touch bad")
        with self.assertRaises(ValueError): defaults.choose("browser", "Alacritty.desktop")

    def test_browser_updates_standard_handlers_as_separate_arguments(self):
        defaults.choose("browser", "browser.desktop")
        writes = [call.args[0] for call in self.process.call_args_list if call.args[0][1] == "default"]
        self.assertEqual(writes, [["xdg-mime", "default", "browser.desktop", mime]
            for mime in defaults.CATEGORIES["browser"][1]])

    def test_broken_preferences_are_not_silently_overwritten(self):
        path = defaults.preferences(); path.parent.mkdir(parents=True); path.write_text("broken")
        with self.assertRaises(ValueError): defaults.choose("terminal", "kitty.desktop")
        self.assertEqual(path.read_text(), "broken")

    def test_alacritty_argv_preserves_directory_title_and_command(self):
        self.assertEqual(defaults.terminal_command(Path("/a b"), ["bash", "-c", "printf '$HOME'"], "Network"),
            ["alacritty", "--working-directory", str(Path("/a b")), "--title", "Network", "-e", "bash", "-c", "printf '$HOME'"])

class LauncherDefaultRanking(unittest.TestCase):
    def test_default_terminal_wins_even_when_its_name_does_not_match(self):
        import shutil
        executable = shutil.which("node")
        if not executable: self.skipTest("Node is needed only by this development test")
        source = (SCRIPTS.parent / "config/quickshell/forynarch/LauncherModel.js").read_text().replace(".pragma library", "")
        test = source + '''
const entries=[{id:"other.desktop",name:"Terminal",keywords:["terminal"]},{id:"Alacritty",name:"Alacritty"}];
if(search(entries,"terminal","Alacritty.desktop")[0].name!=="Alacritty")throw Error("default not first");
if(search(entries,"browser","Alacritty.desktop").length)throw Error("unrelated result");
'''
        subprocess.run([executable, "-e", test], check=True, capture_output=True)
