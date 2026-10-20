"""Policy and real helper behavior, using disposable command fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("hotkeys", ROOT / "scripts/hotkeys.py")
hotkeys = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hotkeys)


class HotkeyPolicy(unittest.TestCase):
    def test_protected_shortcuts_and_swap(self):
        rows = {r["keys"]: r for r in hotkeys.bindings()}
        for key, command in {"SUPER + SPACE": "forynarch-launcher", "SUPER + Q": "forynarch-terminal", "SUPER + E": "forynarch-files"}.items():
            self.assertEqual(rows[key]["command"], command)
        self.assertIn("window.close", rows["SUPER + C"]["code"])
        self.assertIn("window.float", rows["SUPER + V"]["code"])
        for direction in ("left", "right", "up", "down"):
            self.assertIn("dsp.focus", rows[f"SUPER + {direction}"]["code"])
            self.assertIn("window.swap", rows[f"SUPER + SHIFT + {direction}"]["code"])
        self.assertNotIn("SUPER + M", rows)

    def test_generated_files_are_current(self):
        self.assertEqual((ROOT / "config/hypr/bindings.lua").read_text(encoding="utf-8"), hotkeys.lua_text())
        self.assertEqual((ROOT / "config/quickshell/forynarch/HotkeysModel.js").read_text(encoding="utf-8"), hotkeys.js_text())
        self.assertEqual((ROOT / "config/forynarch/hotkeys.txt").read_text(encoding="utf-8"), hotkeys.text_text())

    def test_five_slots_and_no_missing_application_dependencies(self):
        rows = hotkeys.bindings()
        focus = [r["command"] for r in rows if r.get("command", "").startswith("forynarch-workspace focus ")]
        self.assertEqual(focus, [f"forynarch-workspace focus {i}" for i in range(1, 6)])
        for row in rows:
            self.assertNotRegex(row.get("command", ""), r"\b(python|node|npm|git|docker|code|obsidian)\b")


@unittest.skipUnless(os.name != "nt" and shutil.which("bash") and shutil.which("jq"), "Requires Arch/Linux Bash and jq")
class NativeSettingsBehavior(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ("bin", "runtime", "config"):
            (self.root / name).mkdir()
        self.env = dict(os.environ, PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                        XDG_RUNTIME_DIR=str(self.root / "runtime"), XDG_CONFIG_HOME=str(self.root / "config"))
        self.stub("hyprctl", '''case "$*" in
          '-j monitors'|'-j monitors all') cat "$PWD/monitors.json";;
          '-j activeworkspace') cat "$PWD/active.json";;
          '-j clients') cat "$PWD/clients.json";;
          *) printf '%s\\n' "$*" >> "$PWD/actions";;
        esac''')
        self.monitors([self.monitor("A", True)])
        (self.root / "active.json").write_text('{"id":1}')

    def stub(self, name, body):
        path = self.root / "bin" / name
        path.write_text("#!/usr/bin/env bash\n" + body + "\n", newline="\n")
        path.chmod(0o755)

    @staticmethod
    def monitor(name, focused, serial=""):
        return dict(name=name, focused=focused, make="Test", model="Panel", serial=serial, width=1280,
                    height=800, refreshRate=60, scale=1, x=0, y=0, transform=0, availableModes=["1280x800@60Hz"])

    def monitors(self, value):
        (self.root / "monitors.json").write_text(json.dumps(value))

    def run_helper(self, script, *args):
        return subprocess.run(["bash", str(ROOT / "scripts" / script), *args], cwd=self.root,
                              env=self.env, capture_output=True, text=True)

    def actions(self):
        path = self.root / "actions"
        return path.read_text() if path.exists() else ""

    def test_monitor_slots_survive_order_and_connector_changes(self):
        self.monitors([self.monitor("A", True, "serial-a"), self.monitor("B", False, "serial-b")])
        self.assertEqual(self.run_helper("forynarch-workspace.sh", "focus", "3").returncode, 0)
        self.assertIn("workspace=3", self.actions())
        self.monitors([self.monitor("B", True, "serial-b"), self.monitor("A", False, "serial-a")])
        self.assertEqual(self.run_helper("forynarch-workspace.sh", "focus", "3").returncode, 0)
        self.assertIn("workspace=8", self.actions())
        self.monitors([self.monitor("NewPort", True, "serial-a"), self.monitor("B", False, "serial-b")])
        self.run_helper("forynarch-workspace.sh", "focus", "2")
        self.assertIn("workspace=2", self.actions().splitlines()[-1])

    def test_local_slot_wrap_and_invalid_mapping(self):
        (self.root / "active.json").write_text('{"id":5}')
        self.assertEqual(self.run_helper("forynarch-workspace.sh", "next").returncode, 0)
        self.assertIn("workspace=1", self.actions())
        path = self.root / "config/forynarch/monitor-slots.json"
        path.write_text('{"A":0,"B":0}')
        before = self.actions()
        self.assertNotEqual(self.run_helper("forynarch-workspace.sh", "focus", "2").returncode, 0)
        self.assertEqual(before, self.actions())

    def test_mru_frozen_cycle_and_release_reset(self):
        clients = [dict(address=f"0x{i}", mapped=True, hidden=False, workspace={"id":1}, focusHistoryID=i-1) for i in (1, 2, 3)]
        path = self.root / "clients.json"
        path.write_text(json.dumps(clients))
        self.assertEqual(self.run_helper("forynarch-window-switcher.sh", "next").returncode, 0)
        self.assertIn("address:0x2", self.actions(), (self.root / "runtime/forynarch-window-cycle.json").read_text() if (self.root / "runtime/forynarch-window-cycle.json").exists() else "No cycle state")
        clients[0]["focusHistoryID"], clients[1]["focusHistoryID"] = 1, 0
        path.write_text(json.dumps(clients))
        self.run_helper("forynarch-window-switcher.sh", "next")
        self.assertIn("address:0x3", self.actions().splitlines()[-1])
        self.run_helper("forynarch-window-switcher.sh", "previous")
        self.assertIn("address:0x2", self.actions().splitlines()[-1])
        self.run_helper("forynarch-window-switcher.sh", "reset")
        self.assertFalse((self.root / "runtime/forynarch-window-cycle.json").exists())

    def test_alt_tab_restores_only_minimized_windows_from_current_workspace(self):
        clients = [dict(address="0x1", pid=1, mapped=True, hidden=False, floating=True,
                        workspace={"id":1,"name":"1"}, focusHistoryID=0),
                   dict(address="0x2", pid=2, mapped=True, hidden=True, floating=True,
                        workspace={"id":-99,"name":"special:forynarch-minimized"}, focusHistoryID=-1),
                   dict(address="0x3", pid=3, mapped=True, hidden=True,
                        workspace={"id":-99,"name":"special:forynarch-minimized"}, focusHistoryID=-1)]
        (self.root/"clients.json").write_text(json.dumps(clients))
        directory=self.root/"runtime/forynarch-windows";directory.mkdir()
        (directory/"minimized.json").write_text(json.dumps({"0x2":{"pid":2,"workspace":1},"0x3":{"pid":3,"workspace":2}}))
        self.stub("forynarch-window-control",'printf "%s\\n" "$*" >> "$PWD/actions"')
        result=self.run_helper("forynarch-window-switcher.sh","next")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.actions().strip(),"activate 0x2")
        self.run_helper("forynarch-window-switcher.sh","reset")
        clients[1]["pid"]=99
        (self.root/"clients.json").write_text(json.dumps(clients))
        before=self.actions()
        result=self.run_helper("forynarch-window-switcher.sh","next")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn("activate",self.actions()[len(before):])

    def test_invalid_preferences_never_dispatch_or_persist(self):
        for key, value in (("keyboardLayout", 'us"})'), ("fpsOverlay", "1"), ("idleSleep", "300"), ("sensitivity", "9"), ("unknown", "true"),
                ("windowGap", "-1"), ("screenMargin", "65"), ("cornerRadius", "40.5"), ("cornerRadius", "true"),
                ("focusTiled", "1"), ("focusFloating", '"yes"'), ("focusColor", '#fff"})')):
            with self.subTest(key=key):
                result = self.run_helper("forynarch-system.sh", "set", key, value)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.actions(), "")
                self.assertFalse((self.root / "config/forynarch/system.json").exists())

    def test_mru_stays_in_active_workspace_and_drops_closed_windows(self):
        clients = [dict(address=f"0x{i}", mapped=True, hidden=False, workspace={"id":workspace}, focusHistoryID=i-1) for i, workspace in ((1,1),(2,1),(3,2))]
        path = self.root / "clients.json"
        path.write_text(json.dumps(clients))
        self.run_helper("forynarch-window-switcher.sh", "next")
        self.assertIn("address:0x2", self.actions())
        path.write_text(json.dumps(clients[:1]))
        self.run_helper("forynarch-window-switcher.sh", "next")
        self.assertIn("address:0x1", self.actions().splitlines()[-1])
        self.assertNotIn("address:0x3", self.actions())

    def test_valid_preference_persists_without_idle_service(self):
        self.stub("systemctl", 'echo service-called >> "$PWD/actions"; exit 99')
        result = self.run_helper("forynarch-system.sh", "set", "fpsOverlay", "true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads((self.root / "config/forynarch/system.json").read_text())["fpsOverlay"])
        self.assertIn("overlay=true", self.actions())
        self.assertNotIn("service-called", self.actions())

    def test_window_geometry_settings_apply_and_persist(self):
        for key in ("windowGap", "screenMargin", "cornerRadius"):
            result = self.run_helper("forynarch-system.sh", "set", key, "0")
            self.assertEqual(result.returncode, 0, result.stderr)
        saved = json.loads((self.root / "config/forynarch/system.json").read_text())
        self.assertTrue(all(saved[key] == 0 for key in ("windowGap", "screenMargin", "cornerRadius")))
        module = (self.root / "config/hypr/system-settings.lua").read_text()
        self.assertIn("gaps_in=0,gaps_out=0", module)
        self.assertIn("rounding=0", module)

    def test_existing_preferences_gain_window_defaults(self):
        directory = self.root / "config/forynarch"
        directory.mkdir(parents=True)
        (directory / "system.json").write_text('{"fpsOverlay":true}')
        result = self.run_helper("forynarch-system.sh", "preferences")
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = json.loads(result.stdout)
        self.assertTrue(saved["fpsOverlay"])
        self.assertEqual((saved["windowGap"], saved["screenMargin"], saved["cornerRadius"]), (6,14,10))

    def test_idle_service_failure_does_not_persist_new_policy(self):
        self.stub("systemctl", 'echo service-called >> "$PWD/actions"; exit 99')
        result = self.run_helper("forynarch-system.sh", "set", "idleBlank", "300")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Previous preferences were retained", result.stderr)
        self.assertFalse((self.root / "config/forynarch/system.json").exists())
        self.assertNotIn("timeout = 300", (self.root / "config/hypr/forynarch-idle.conf").read_text())

    def test_idle_order_rejects_sleep_before_lock(self):
        for value in ({"idleLock":900,"idleBlank":300}, {"idleLock":900,"idleSleep":900}, {"idleBlank":900,"idleSleep":900}):
            result = subprocess.run(["jq", "-f", str(ROOT / "scripts/system-settings-model.jq")], input=json.dumps(value), capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)

    def test_display_rejects_unreported_mode_fractional_pixels_and_extreme_position(self):
        for mode, scale, position in (("1920x1080@60", "1", "auto"), ("1280x800@60", "1.75", "auto"), ("1280x800@60", "1", "999999x0")):
            result = self.run_helper("forynarch-display.sh", "preview", "A", mode, scale, position, "0")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.actions(), "")

    def display_fixture(self):
        transaction = self.root / "runtime/forynarch-display-preview"
        transaction.mkdir()
        (transaction / "pending").write_text("token.current\n")
        (transaction / "rollback.lua").write_text("ROLLBACK\n")
        (transaction / "proposed.lua").write_text('hl.monitor({output="A",mode="1280x800@60",scale=1})\n')
        return transaction

    def test_display_stale_guard_cannot_revert_new_preview(self):
        transaction = self.display_fixture()
        self.assertEqual(self.run_helper("forynarch-display.sh", "revert-token", "token.old").returncode, 0)
        self.assertTrue((transaction / "pending").exists())
        self.assertEqual(self.actions(), "")
        self.run_helper("forynarch-display.sh", "revert-token", "token.current")
        self.assertIn("ROLLBACK", self.actions())
        self.assertFalse((transaction / "pending").exists())

    def test_keep_preserves_other_monitor_and_cancels_rollback(self):
        transaction = self.display_fixture()
        path = self.root / "config/hypr/monitors.lua"
        path.parent.mkdir()
        path.write_text('hl.monitor({output="B",mode="preferred"})\nhl.monitor({output="A",mode="old"})\n')
        self.assertEqual(self.run_helper("forynarch-display.sh", "keep").returncode, 0)
        self.assertIn('output="B"', path.read_text())
        self.assertNotIn('mode="old"', path.read_text())
        self.assertFalse((transaction / "pending").exists())
        self.run_helper("forynarch-display.sh", "revert-token", "token.current")
        self.assertEqual(self.actions(), "")


if __name__ == "__main__":
    unittest.main()
