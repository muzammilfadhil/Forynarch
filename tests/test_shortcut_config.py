"""Input safety, collision ownership and failed-write recovery."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == "nt", "Requires the Linux flock implementation")
class ShortcutConfiguration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("shortcut_config", ROOT / "scripts/forynarch-shortcut-config.py")
        cls.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.helper)

    def test_modifier_order_and_aliases_share_one_identity(self):
        self.assertEqual(self.helper.canonical("Shift + Win + Ctrl + Enter"), "SUPER + CTRL + SHIFT + RETURN")
        self.assertEqual(self.helper.canonical("super + ."), "SUPER + PERIOD")
        self.assertEqual(self.helper.canonical("Super + mouse:273"), "SUPER + mouse:273")
        self.assertEqual(self.helper.canonical(""), "")

    def test_rejects_code_and_repeated_modifiers(self):
        for value in ('SUPER + E");os.execute("bad")', "Super + Win + E", "SUPER + ", "Super + mouse:999"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.helper.canonical(value)

    def test_managed_and_external_collisions(self):
        rows = [dict(id="a", title="Files", keys="SUPER + E"), dict(id="b", title="Search", keys="SUPER + SPACE")]
        live = [dict(description="Files", key="E", modmask=64)]
        self.assertEqual(self.helper.conflicts(rows, {}, live, {}), [])
        self.assertEqual(self.helper.conflicts(rows, {"a":"SUPER + SPACE"}, live, {})[0]["other"], "Files")
        live.append(dict(description="My action", key="F12", modmask=68))
        self.assertEqual(self.helper.conflicts(rows, {"a":"SUPER + CTRL + F12"}, live, {})[0]["other"], "My action")
        self.assertEqual(self.helper.conflicts(rows, {"a":""}, live, {}), [])

    def test_disabling_a_conflicted_key_cannot_erase_an_external_binding(self):
        rows = [dict(id="a",title="Files",keys="SUPER + E")]
        live = [dict(description="My action",key="E",modmask=64)]
        self.assertEqual(self.helper.conflicts(rows, {"a":""}, live, {})[0]["other"], "My action")

    def test_compositor_failure_restores_both_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            module, document = Path(temporary) / "bindings.lua", Path(temporary) / "shortcuts.json"
            module.write_text("previous Lua")
            document.write_text("previous JSON")
            with patch.object(self.helper.subprocess, "run", side_effect=[subprocess.CompletedProcess([], 0, "Lua error"), subprocess.CompletedProcess([], 0)]):
                with self.assertRaises(ValueError):
                    self.helper.apply(module, "new Lua", document, "new JSON")
            self.assertEqual(module.read_text(), "previous Lua")
            self.assertEqual(document.read_text(), "previous JSON")

    def test_all_shipped_bindings_have_unique_ids_and_canonical_keys(self):
        rows = json.loads((ROOT / "config/forynarch/shortcut-catalog.json").read_text())["bindings"]
        self.assertEqual(len(rows), len({row["id"] for row in rows}))
        self.assertEqual(len(rows), len({self.helper.canonical(row["keys"]) for row in rows}))

    def test_snap_observers_do_not_conflict_but_foreign_bindings_do(self):
        rows = [dict(id="drag", title="Move window", keys="SUPER + mouse:272")]
        observer = dict(description="Observe floating drag", key="mouse:272", modmask=64, non_consuming=True)
        self.assertEqual(self.helper.conflicts(rows, {}, [observer], {}), [])
        foreign = dict(observer, description="User pointer action")
        self.assertEqual(self.helper.conflicts(rows, {}, [foreign], {})[0]["other"], "User pointer action")
        text = self.helper.render(rows, {"drag":"CTRL + mouse:272"}, {})
        self.assertIn('forynarch_snap_rebind({"SUPER + mouse:272"})', text)

    def test_user_module_resolves_updated_factory_actions(self):
        rows = [dict(id="arrow",title="Focus right",keys="SUPER + RIGHT",code="old_action()")]
        module = self.helper.render(rows, {"arrow":"CTRL + RIGHT"}, {})
        self.assertIn('forynarch_shortcuts["arrow"].dispatcher', module)
        self.assertNotIn("old_action", module)

    def test_document_write_failure_restores_working_bindings(self):
        with tempfile.TemporaryDirectory() as temporary:
            module, document = Path(temporary) / "bindings.lua", Path(temporary) / "shortcuts.json"
            module.write_text("previous Lua")
            document.write_text("previous JSON")
            original = self.helper.atomic
            def failing_write(path, text):
                if path == document and text == "new JSON":
                    raise OSError("Simulated disk full")
                original(path, text)
            with patch.object(self.helper, "atomic", side_effect=failing_write), patch.object(self.helper.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "ok")):
                with self.assertRaises(OSError):
                    self.helper.apply(module, "new Lua", document, "new JSON")
            self.assertEqual(module.read_text(), "previous Lua")
            self.assertEqual(document.read_text(), "previous JSON")


if __name__ == "__main__":
    unittest.main()
