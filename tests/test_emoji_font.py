import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("emoji_font", ROOT / "scripts/forynarch-emoji-font.py")
font = importlib.util.module_from_spec(spec)
spec.loader.exec_module(font)


@unittest.skipIf(os.name == "nt", "Linux font paths and fontconfig")
class EmojiFont(unittest.TestCase):
    def test_remote_urls_are_never_downloaded(self):
        with patch.object(font.subprocess, "run") as command:
            for url in ("https://example.org/font.ttf", "file://remote/font.ttf"):
                with self.assertRaises(ValueError):
                    font.install(url)
            command.assert_not_called()

    def test_invalid_font_does_not_create_installation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "broken.ttf"
            source.write_bytes(b"invalid")
            with patch.dict(os.environ, XDG_DATA_HOME=str(root / "data")), patch.object(font.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "fc-scan")):
                with self.assertRaises(subprocess.SubprocessError):
                    font.install(str(source))
            self.assertFalse((root / "data").exists())

    def test_user_install_is_idempotent_and_escapes_font_names(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "local.ttf"
            source.write_bytes(b"fixture font")
            def command(args, **kwargs):
                return subprocess.CompletedProcess(args, 0, 'Example & Emoji\n' if args[0] == "fc-scan" else "", "")
            with patch.dict(os.environ, XDG_DATA_HOME=str(root / "data"), XDG_CONFIG_HOME=str(root / "config")), patch.object(font.subprocess, "run", side_effect=command):
                first = font.install(source.as_uri())
                second = font.install(str(source))
            self.assertEqual(first, second)
            self.assertEqual(len(list((root / "data/fonts/forynarch-emoji").iterdir())), 1)
            config = ET.parse(root / "config/fontconfig/conf.d/60-forynarch-emoji.conf")
            self.assertEqual(config.findtext("alias/prefer/family"), "Example & Emoji")


if __name__ == "__main__":
    unittest.main()
