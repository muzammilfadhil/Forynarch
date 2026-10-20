import copy
import errno
import importlib.util
import json
import os
import shutil
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("widget_packs", ROOT / "scripts/forynarch-widget-packs.py")
packs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packs)
EXAMPLE = json.loads((ROOT / "examples/widget-packs/workday.json").read_text())


class WidgetPackValidation(unittest.TestCase):
    def test_browse_exposes_folders_and_json_without_opening_other_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Subfolder").mkdir()
            (root / "chosen.json").write_text("{}")
            (root / "private.txt").write_text("not a pack")
            (root / ".hidden.json").write_text("{}")
            result = packs.browse(str(root))
            self.assertEqual(result["entries"], [{"name":"Subfolder","folder":True},{"name":"chosen.json","folder":False}])
            self.assertEqual(result["parent"], str(root.parent))

    def test_example_is_valid_and_has_stable_digest(self):
        self.assertEqual(packs.validate(copy.deepcopy(EXAMPLE)), EXAMPLE)
        self.assertEqual(packs.digest(EXAMPLE), packs.digest(json.loads(json.dumps(EXAMPLE, sort_keys=True))))

    def test_code_paths_and_remote_sources_are_rejected(self):
        for field, value in (("command", "touch /tmp/test"), ("entrypoint", "../../Widget.qml"), ("url", "https://example.com")):
            data = copy.deepcopy(EXAMPLE)
            data[field] = value
            with self.subTest(field=field), self.assertRaises(packs.PackError):
                packs.validate(data)
        data = copy.deepcopy(EXAMPLE)
        data["widgets"][0]["items"][0]["kind"] = "qml"
        with self.assertRaises(packs.PackError):
            packs.validate(data)

    def test_duplicate_ids_bad_sizes_and_unknown_tokens_are_rejected(self):
        changes = (lambda p:p["widgets"].append(p["widgets"][0]), lambda p:p["widgets"][0].update(height=100000), lambda p:p["widgets"][0]["items"][0].update(size=True), lambda p:p["widgets"][0]["items"][0].update(text="{shell}"), lambda p:p.update(id="../../etc"))
        for change in changes:
            data = copy.deepcopy(EXAMPLE)
            change(data)
            with self.assertRaises(packs.PackError):
                packs.validate(data)

    def test_oversized_duplicate_and_nonfinite_json_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pack.json"
            for content in (" " * (packs.LIMIT + 1), '{"id":"a","id":"b"}', '{"value":NaN}'):
                path.write_text(content)
                with self.assertRaises((packs.PackError, ValueError)):
                    packs.read_pack(path)

    def test_remote_file_urls_are_rejected(self):
        for value in ("https://example.com/widgets.json", "file://remote/share/widgets.json"):
            with self.assertRaises(packs.PackError):
                packs.local_path(value)
        self.assertEqual(packs.local_path("file:///tmp/a%20b.json"), Path("/tmp/a b.json"))


@unittest.skipIf(os.name == "nt", "Native Linux CLI paths")
class WidgetPackLifecycle(unittest.TestCase):
    def test_editable_sources_change_user_config_without_touching_factory(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_DATA_HOME": directory+"/data", "XDG_CONFIG_HOME": directory+"/config"}):
            active = Path(directory) / "config/quickshell/forynarch"
            shutil.copytree(ROOT / "config/quickshell/forynarch", active)
            result = packs.main(["sources"])
            link = Path(result["folder"]) / "DesktopWidgets.qml"
            self.assertTrue(link.is_symlink())
            original = (ROOT / "config/quickshell/forynarch/DesktopWidgets.qml").read_text()
            link.write_text("// user-owned widget edit\n" + original)
            self.assertTrue((active / "DesktopWidgets.qml").read_text().startswith("// user-owned widget edit"))
            self.assertEqual((ROOT / "config/quickshell/forynarch/DesktopWidgets.qml").read_text(), original)
            self.assertEqual(packs.main(["sources"])["folder"], result["folder"])

    def test_export_without_hardlinks_still_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "shared.json"
            with patch.object(packs.os, "link", side_effect=OSError(errno.EPERM, "No hardlinks")):
                packs.atomic_write(destination, EXAMPLE)
                self.assertEqual(json.loads(destination.read_text()), EXAMPLE)
                with self.assertRaises(packs.PackError):
                    packs.atomic_write(destination, EXAMPLE)

    def test_inspect_import_export_remove_and_review_digest(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_DATA_HOME": directory}):
            path = Path(directory) / "chosen file.json"
            path.write_text(json.dumps(EXAMPLE))
            review = packs.main(["inspect", path.as_uri()])
            self.assertTrue(review["dataOnly"])
            self.assertEqual(packs.main(["list"])["packs"], [])
            with self.assertRaises(packs.PackError):
                packs.main(["import", str(path), "--expected-digest", "wrong"])
            packs.main(["import", str(path), "--expected-digest", review["digest"]])
            self.assertEqual(packs.main(["list"])["packs"], [EXAMPLE])
            with self.assertRaises(packs.PackError):
                packs.main(["import", str(path)])
            exported = Path(directory) / "export.json"
            packs.main(["export", "workday", str(exported)])
            self.assertEqual(json.loads(exported.read_text()), EXAMPLE)
            with self.assertRaises(packs.PackError):
                packs.main(["export", "workday", str(exported)])
            packs.main(["remove", "workday"])
            self.assertEqual(packs.main(["list"])["packs"], [])
            self.assertTrue(exported.exists())

    def test_invalid_registry_files_and_symlinks_do_not_load(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_DATA_HOME": directory}):
            base = packs.folder()
            outside = Path(directory) / "outside.json"
            outside.write_text(json.dumps(EXAMPLE))
            (base / "workday.json").symlink_to(outside)
            result = packs.main(["list"])
            self.assertEqual(result["packs"], [])
            self.assertTrue(result["warnings"])
            with self.assertRaises(packs.PackError):
                packs.main(["remove", "workday"])
            self.assertTrue(outside.exists())
