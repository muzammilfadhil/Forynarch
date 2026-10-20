import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('wallpaper',Path(__file__).resolve().parents[1]/'scripts/forynarch-wallpaper.py')
wallpaper=importlib.util.module_from_spec(spec);spec.loader.exec_module(wallpaper)

class Wallpaper(unittest.TestCase):
    def test_file_uri_with_spaces_survives_original_removal(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'my picture.png';source.write_bytes(b'local image fixture')
            with patch.dict(os.environ,{'XDG_CONFIG_HOME':str(root/'config'),'XDG_DATA_HOME':str(root/'data')}),patch.object(wallpaper.subprocess,'run'),patch.object(wallpaper.time,'sleep'):
                result=wallpaper.select(source.as_uri());source.unlink()
                self.assertEqual(Path(result['image']).read_bytes(),b'local image fixture')
                self.assertEqual(wallpaper.chosen(),result['image'])

    def test_renderer_failure_restores_previous_choice(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'new.png';source.write_bytes(b'image fixture');old=root/'old.png';old.write_bytes(b'old fixture')
            with patch.dict(os.environ,{'XDG_CONFIG_HOME':str(root/'config'),'XDG_DATA_HOME':str(root/'data')}):
                wallpaper.write_preferences({'image':str(old)})
                with patch.object(wallpaper.subprocess,'run',side_effect=[subprocess.CalledProcessError(1,['systemctl']),None]),self.assertRaises(ValueError):wallpaper.select(str(source))
                self.assertEqual(wallpaper.chosen(),str(old))

    def test_remote_uri_and_non_image_are_rejected(self):
        for value in ('https://example.com/image.png','file://remote/tmp/a.png'):
            with self.subTest(value=value),self.assertRaises(ValueError):wallpaper.local_image(value)
        with tempfile.TemporaryDirectory() as temporary:
            source=Path(temporary)/'file.txt';source.write_text('not an image')
            with self.assertRaises(ValueError):wallpaper.local_image(str(source))
