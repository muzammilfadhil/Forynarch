import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("capture", ROOT / "scripts/forynarch-capture.py")
capture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture)
PNG = b"\x89PNG\r\n\x1a\nfixture"


class Capture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        env = patch.dict(os.environ, {"XDG_CONFIG_HOME":str(self.root/"config"), "XDG_STATE_HOME":str(self.root/"state"), "CLIPBOARD_STATE":"data"})
        env.start();self.addCleanup(env.stop)
        defaults = patch.object(capture, "defaults", return_value=dict(saveFiles=True, copyClipboard=True,
                               directory=str(self.root/"Screenshots"), historyEnabled=False))
        defaults.start();self.addCleanup(defaults.stop)

    def test_destinations_require_a_file_or_clipboard_and_validate_before_write(self):
        capture.set_preference("saveFiles", "false")
        original = capture.locations()[0].read_bytes()
        for key, value in (("copyClipboard","false"),("directory","relative/path"),("directory","/bad\npath"),("saveFiles","yes")):
            with self.subTest(key=key, value=value):
                with self.assertRaises(ValueError):capture.set_preference(key,value)
                self.assertEqual(capture.locations()[0].read_bytes(),original)

    def test_fullscreen_saves_png_and_copies_the_same_image(self):
        with patch.object(capture.subprocess,"run") as run:
            run.side_effect=lambda command,**kw: subprocess.CompletedProcess(command,0,PNG if command[0]=="grim" else b"",b"")
            result=capture.screenshot("fullscreen")
            self.assertEqual(Path(result["saved"]).read_bytes(),PNG)
            self.assertTrue(result["copied"])
            self.assertFalse(any(c.args[0][0]=="slurp" for c in run.call_args_list))
            copied=next(c for c in run.call_args_list if c.args[0][0]=="wl-copy")
            self.assertEqual(copied.kwargs["input"],PNG)

    def test_clipboard_only_never_creates_a_screenshot_folder(self):
        capture.set_preference("saveFiles","false")
        with patch.object(capture.subprocess,"run") as run:
            run.side_effect=lambda command,**kw:subprocess.CompletedProcess(command,0,PNG if command[0]=="grim" else b"",b"")
            result=capture.screenshot("fullscreen")
        self.assertEqual(result,{"saved":"","copied":True})
        self.assertFalse((self.root/"Screenshots").exists())

    def test_region_cancel_does_not_write_a_file_or_clipboard(self):
        with patch.object(capture.subprocess,"run",return_value=subprocess.CompletedProcess(["slurp"],1,"","")) as run:
            self.assertEqual(capture.screenshot("region"),{"cancelled":True})
            self.assertEqual(run.call_count,1)
        self.assertFalse((self.root/"Screenshots").exists())

    def test_region_geometry_is_an_argument_without_shell_expansion(self):
        geometry="-1920,80 640x480"
        def execute(command,**kwargs):
            return subprocess.CompletedProcess(command,0,geometry+"\n" if command[0]=="slurp" else PNG if command[0]=="grim" else b"",b"")
        with patch.object(capture.subprocess,"run",side_effect=execute) as run:
            capture.screenshot("region")
        grim=next(c for c in run.call_args_list if c.args[0][0]=="grim")
        self.assertEqual(grim.args[0],["grim","-g",geometry,"-"])
        self.assertFalse(grim.kwargs.get("shell",False))

    def test_history_is_opt_in_and_skips_sensitive_or_empty_events(self):
        capture.store("text/plain",b"not stored")
        self.assertFalse(capture.locations()[1].exists())
        capture.set_preference("historyEnabled","true")
        for state in ("sensitive","nil","clear"):
            with patch.dict(os.environ,{"CLIPBOARD_STATE":state}):capture.store("text/plain",b"secret")
        capture.store("text/plain",b"")
        self.assertEqual(capture.history("list"),[])

    def test_history_deduplicates_bounds_and_keeps_raw_text_only_in_database(self):
        capture.set_preference("historyEnabled","true")
        with patch.object(capture,"MAX_ENTRIES",3):
            for value in (b"a",b"b",b"c",b"d",b"d"):capture.store("text/plain",value)
        rows=capture.history("list")
        self.assertEqual([r["preview"] for r in rows],["d","c","b"])
        if os.name!="nt":self.assertEqual(capture.locations()[1].stat().st_mode&0o777,0o600)
        with patch.object(capture,"MAX_TOTAL",3):capture.store("text/plain",b"xyz")
        self.assertEqual([r["preview"] for r in capture.history("list")],["xyz"])

    def test_copy_delete_and_clear_are_scoped_and_clear_current_selections(self):
        capture.set_preference("historyEnabled","true")
        secret=b"unique clipboard fixture 548287"
        capture.store("text/plain",secret)
        identifier=capture.history("list")[0]["id"]
        with patch.object(capture.subprocess,"run") as run:
            capture.history("copy",str(identifier))
            self.assertEqual(run.call_args.kwargs["input"],secret)
            capture.history("delete",str(identifier))
            self.assertEqual(capture.history("list"),[])
            capture.store("image/png",PNG)
            capture.history("clear")
            self.assertTrue(any(c.args[0]==["wl-copy","--clear"] for c in run.call_args_list))
            self.assertTrue(any(c.args[0]==["wl-copy","--primary","--clear"] for c in run.call_args_list))
        self.assertEqual(capture.history("list"),[])
        self.assertNotIn(secret,capture.locations()[1].read_bytes())

    def test_large_or_unrecognized_data_is_not_retained(self):
        capture.set_preference("historyEnabled","true")
        with patch.object(capture,"MAX_ITEM",3):capture.store("text/plain",b"four")
        capture.store("image/png",b"not an image")
        capture.store("application/octet-stream",b"binary")
        self.assertEqual(capture.history("list"),[])


if __name__=="__main__":unittest.main()
