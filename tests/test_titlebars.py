"""Titlebar exceptions persist without wildcard leaks or changes to window modes."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('titlebars', ROOT / 'scripts/forynarch-titlebars.py')
titlebars = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(titlebars)


class Titlebars(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.paths = (self.root / 'config/titlebars.json', self.root / 'config/rules.lua', self.root / 'state/classes.json')
        patcher = patch.object(titlebars, 'locations', return_value=self.paths)
        patcher.start(); self.addCleanup(patcher.stop)
        self.groups = titlebars.catalog()
        self.prefs = titlebars.preferences()

    def test_defaults_cover_native_apps_without_hiding_webapp_controls(self):
        for app in ['Google-chrome', 'chromium', 'discord', 'DiscordCanary', 'vesktop', 'steam', 'me.muzammilfadhil.mudilmusic', 'org.gnome.TextEditor']:
            self.assertTrue(titlebars.native(app, self.prefs, self.groups), app)
        for app in ['Alacritty', 'kitty', 'forynarch-webapp-12345678-abcd-1234-abcd-123456789abc', 'chrome-forynarch-webapp-12345678-abcd-1234-abcd-123456789abc-Default', 'Google-chrome-forynarch-webapp-12345678-abcd-1234-abcd-123456789abc-Default', 'steam_app_12345', 'org.kde.konsole']:
            self.assertFalse(titlebars.native(app, self.prefs, self.groups), app)

    def test_manual_override_is_independent_of_common_defaults(self):
        self.prefs['exclusions'] = ['obsidian']
        self.prefs['inclusions'] = ['discord']
        self.assertFalse(titlebars.native('discord', self.prefs, self.groups))
        self.assertTrue(titlebars.native('Obsidian', self.prefs, self.groups))
        self.prefs['useDefaults'] = False
        self.assertFalse(titlebars.native('chrome', self.prefs, self.groups))
        self.assertTrue(titlebars.native('obsidian', self.prefs, self.groups))

    def test_exact_classes_are_escaped_in_lua_rules(self):
        self.prefs['exclusions'] = ['my.app.*"\\']
        text = titlebars.rules(self.prefs, self.groups)
        custom = next(row for row in text.splitlines() if 'forynarch-titlebar-app-' in row)
        self.assertIn('float=true', custom)
        self.assertIn('\\\\.', custom)
        self.assertNotIn('hl.dsp', text)
        self.assertNotIn('decorate=', text)
        for value in ['bad\nclass', '', 'x' * 161]:
            with self.assertRaises(ValueError):
                titlebars.app_class(value)

    def test_removed_exception_is_disabled_in_live_compositor_rules(self):
        text = titlebars.rules(self.prefs, self.groups, ['removed.app'])
        row = next(line for line in text.splitlines() if 'forynarch-titlebar-app-' in line)
        self.assertIn('enabled=false', row)
        self.assertIn('float=true', row)

    def test_global_off_cannot_be_overridden_by_an_earlier_force_titlebar_rule(self):
        self.prefs['enabled'] = False
        self.prefs['inclusions'] = ['discord']
        text = titlebars.rules(self.prefs, self.groups)
        row = next(line for line in text.splitlines() if 'forynarch-titlebar-app-' in line)
        self.assertIn('["hyprbars:no_bar"]="true"', row)
        self.assertTrue(titlebars.native('discord', self.prefs, self.groups))

    def test_preferences_survive_restart_and_apply_saves_rules(self):
        self.prefs['exclusions'] = ['custom.app']
        titlebars.atomic(self.paths[0], json.dumps(self.prefs))
        with patch.dict(os.environ, {}, clear=True):
            titlebars.apply(titlebars.preferences(), self.groups)
        self.assertEqual(titlebars.preferences()['exclusions'], ['custom.app'])
        self.assertEqual(json.loads(self.paths[2].read_text()), ['custom.app'])
        self.assertIn('hyprbars:no_bar', self.paths[1].read_text())

    def test_invalid_preferences_are_not_silently_replaced(self):
        titlebars.atomic(self.paths[0], '{"schema":9}')
        with self.assertRaises(ValueError):
            titlebars.preferences()
        self.assertEqual(self.paths[0].read_text(), '{"schema":9}')

    def test_generated_defaults_match_shipped_rules(self):
        shipped = (ROOT / 'config/hypr/titlebar-defaults.lua').read_text()
        self.assertEqual(titlebars.rules(self.prefs, self.groups), shipped)


if __name__ == '__main__':
    unittest.main()
