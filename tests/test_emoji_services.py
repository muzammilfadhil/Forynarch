"""Emoji catalogue completeness, credential storage and network error handling."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


class EmojiCatalogue(unittest.TestCase):
    def test_search_labels_cover_all_symbols_and_kaomoji(self):
        lines=(ROOT/"config/quickshell/forynarch/EmojiModel.js").read_text(encoding="utf-8").splitlines()
        arrays={line.split("=",1)[0].removeprefix("var ").strip():json.loads(line.split("=",1)[1].strip().removesuffix(";")) for line in lines if line.startswith(("var symbols ","var faces ","var faceNames=","var symbolNames="))}
        self.assertEqual(len(arrays["symbols"]),len(arrays["symbolNames"]))
        self.assertEqual(len(arrays["faces"]),len(arrays["faceNames"]))

    def test_unicode_catalogue_has_complete_sequences_and_english_names(self):
        text=(ROOT/"config/quickshell/forynarch/EmojiData.js").read_text(encoding="utf-8")
        rows=json.loads(text.split("var rows = ",1)[1].removesuffix(";\n"))
        self.assertGreater(len(rows),3900)
        self.assertTrue(any(row["value"]=="💙" and row["name"]=="blue heart" for row in rows))
        self.assertTrue(any("\u200d" in row["value"] for row in rows))
        self.assertTrue(any("skin tone" in row["name"] for row in rows))
        self.assertEqual(len({row["value"] for row in rows}),len(rows))


@unittest.skipUnless(os.name=="posix" and shutil.which("jq"),"Arch shell tools required")
class GiphyService(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name)
        self.env={**os.environ,"HOME":str(self.home),"XDG_CONFIG_HOME":str(self.home/"config")}

    def configure(self,payload):
        return subprocess.run(["bash",str(ROOT/"scripts/forynarch-emoji-config.sh")],input=json.dumps(payload),capture_output=True,text=True,env=self.env)

    def test_key_is_private_and_invalid_updates_do_not_replace_it(self):
        self.assertEqual(self.configure({"apiKey":"FixtureKey123"}).returncode,0)
        path=self.home/"config/forynarch/giphy.json"
        self.assertEqual(path.stat().st_mode & 0o777,0o600)
        for payload in [{"apiKey":"bad\nkey"},{"apiKey":"key","url":"https://evil.example"}]:
            self.assertNotEqual(self.configure(payload).returncode,0)
            self.assertEqual(json.loads(path.read_text())["apiKey"],"FixtureKey123")

    def test_no_key_is_an_offline_nonfatal_state(self):
        result=subprocess.run(["bash",str(ROOT/"scripts/forynarch-giphy.sh"),"cat"],capture_output=True,text=True,env=self.env)
        self.assertEqual(result.returncode,0)
        self.assertEqual(json.loads(result.stdout)["items"],[])
        self.assertIn("API key",json.loads(result.stdout)["error"])
