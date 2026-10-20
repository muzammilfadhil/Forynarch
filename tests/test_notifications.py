import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name=="nt","Requires native user configuration and fcntl")
class Notifications(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec=importlib.util.spec_from_file_location("notifications",ROOT/"scripts/forynarch-notifications.py")
        cls.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.module)

    def test_prepare_preserves_user_rules_and_keeps_include_global(self):
        with tempfile.TemporaryDirectory() as directory,patch.dict(os.environ,{"XDG_CONFIG_HOME":directory}):
            path=Path(directory)/"mako/config";path.parent.mkdir()
            custom='font=Sans 12\n[app-name="Personal"]\nborder-color=#ffffff\n'
            path.write_text(custom)
            for _ in range(2):self.module.prepare(self.module.DEFAULTS)
            result=path.read_text()
            self.assertEqual(result.count("include="),1)
            self.assertTrue(result.startswith("include="));self.assertTrue(result.endswith(custom))
            self.assertEqual(self.module.load(),self.module.DEFAULTS)

    def test_custom_rules_escape_names_and_dnd_wins_over_critical(self):
        settings={**self.module.DEFAULTS,"profile":"custom","allow":['App "quoted" \\ test']}
        rules=self.module.render(self.module.validate(settings))
        self.assertIn('app-name="App \\"quoted\\" \\\\ test"',rules)
        self.assertLess(rules.index('urgency=critical'),rules.index('[mode=do-not-disturb]'))
        self.assertIn('default-timeout=0',rules)
        for update in ({"allow":["bad\nname"]},{"timeout":True},{"timeout":31},{"profile":"shell"},{"extra":"exec anything"}):
            with self.subTest(update=update),self.assertRaises(ValueError):self.module.validate({**settings,**update})

    def test_notification_input_is_bounded_and_history_actions_are_separate(self):
        data=self.module.normalize([{"id":1,"app_name":"Mail","summary":"<b>Literal</b>","body":"X"*5000,"urgency":"critical","actions":{"default":"Open"}},None],True)
        self.assertEqual(len(data),1);self.assertEqual(len(data[0]["body"]),4000)
        self.assertEqual(data[0]["title"],"<b>Literal</b>");self.assertTrue(data[0]["history"])
        self.assertTrue(data[0]["critical"]);self.assertEqual(data[0]["actions"],[{"id":"default","label":"Open"}])

    def test_apply_changes_only_owned_modes_and_updates_badge_once(self):
        calls=[]
        def command(*args,**kwargs):calls.append(args)
        with patch.object(self.module,"prepare"),patch.object(self.module,"command",side_effect=command),patch.dict(os.environ,{"WAYLAND_DISPLAY":""}):
            self.module.apply({**self.module.DEFAULTS,"profile":"custom"})
        self.assertEqual(calls[0],("reload",))
        self.assertIn("-a",calls[1]);self.assertIn("forynarch-custom",calls[1]);self.assertNotIn("-s",calls[1])

    def test_busy_panel_does_not_fail_a_successful_notification_policy(self):
        import subprocess
        with patch.object(self.module,"prepare"),patch.object(self.module,"command") as daemon,patch.dict(os.environ,{"WAYLAND_DISPLAY":"wayland-0"}),patch.object(self.module.subprocess,"run",side_effect=subprocess.TimeoutExpired("qs",.5)):
            self.module.apply({**self.module.DEFAULTS,"profile":"dnd"})
        self.assertEqual(daemon.call_count,2)


@unittest.skipIf(os.name=="nt","Requires Bash staging")
class BrowserPolicy(unittest.TestCase):
    def test_menu_policy_preserves_unrelated_browser_settings(self):
        import subprocess
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/"etc/firefox/policies/policies.json";path.parent.mkdir(parents=True)
            path.write_text(json.dumps({"policies":{"DisableTelemetry":True}}))
            subprocess.run(["bash",str(ROOT/"scripts/configure-browser.sh"),str(root)],check=True)
            self.assertEqual(json.loads(path.read_text()),{"policies":{"DisableTelemetry":True,"DisplayMenuBar":"never"}})
