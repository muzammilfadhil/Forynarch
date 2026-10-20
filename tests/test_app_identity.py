"""Owned app names/icons, header favicons and retained browser profiles."""
import importlib.util
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


identity = module('identity', 'forynarch_app_identity.py')
assets = module('assets', 'forynarch-webapp-assets.py')
WEBAPP_ID = '12345678-abcd-1234-abcd-123456789abc'


class Identity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name)
        self.base = self.data / 'forynarch/webapps'
        self.profile = self.base / WEBAPP_ID
        self.profile.mkdir(parents=True)
        self.metadata = self.base / (WEBAPP_ID + '.json')
        self.value = {'id': WEBAPP_ID, 'name': 'Work mail', 'url': 'https://example.com/mail', 'active': True, 'icon': str(self.profile / 'icon.png')}
        self.metadata.write_text(json.dumps(self.value))
        (self.profile / 'icon.png').write_bytes(b'synthetic fixture')
        self.env = patch.dict(os.environ, {'XDG_DATA_HOME': str(self.data)})
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_mudil_uses_application_logo(self):
        for app in ['me.muzammilfadhil.mudilmusic', 'Mudil Music', 'mudilmusic.desktop', 'com.example.muzo']:
            result = identity.identity({'class': app})
            self.assertEqual(result['displayName'], 'Mudil Music')
            self.assertIn('mudilmusic', result['icon'])
        self.assertEqual(identity.identity({'class': 'unrelated'}), {})

    def test_browser_prefix_keeps_profile_identity(self):
        result = identity.identity({'class': 'chrome-forynarch-webapp-' + WEBAPP_ID + '-Default'})
        self.assertEqual(result['title'], 'Work mail')
        self.assertEqual(result['app'], 'forynarch-webapp-' + WEBAPP_ID)
        self.assertEqual(result['icon'], str(self.profile / 'icon.png'))

    def test_external_icon_and_inactive_profile_are_rejected(self):
        self.value['icon'] = '/etc/passwd'
        self.metadata.write_text(json.dumps(self.value))
        self.assertEqual(identity.identity({'class': 'forynarch-webapp-' + WEBAPP_ID})['icon'], 'applications-internet')
        self.value['active'] = False
        self.metadata.write_text(json.dumps(self.value))
        self.assertEqual(identity.identity({'class': 'forynarch-webapp-' + WEBAPP_ID}), {})

    def test_linked_metadata_is_ignored(self):
        target = self.data / 'other.json'
        target.write_text(self.metadata.read_text())
        self.metadata.unlink()
        try:
            self.metadata.symlink_to(target)
        except OSError:
            self.skipTest('Symlinks unavailable')
        self.assertEqual(identity.identity({'class': 'forynarch-webapp-' + WEBAPP_ID}), {})

    def test_header_favicon_beats_root_fallback_and_cookies_survive(self):
        png = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 32, 32) + b'\0' * 9
        fetched = []
        def download(url, limit, seconds):
            fetched.append(url)
            return b'<head><link rel="shortcut icon" href="/brand/mail.png"></head>' if url.endswith('/mail') else png
        (self.profile / 'cookies').write_text('account fixture')
        with patch.multiple(assets, BASE=self.base, APPLICATIONS=self.data / 'applications', CONFIG=self.data / 'config'), patch.object(assets, 'download', download):
            assets.refresh(self.metadata, assets.time.monotonic() + 5)
            assets.sync()
        self.assertEqual(fetched, ['https://example.com/mail', 'https://example.com/brand/mail.png'])
        desktop = (self.data / 'applications' / ('forynarch-webapp-' + WEBAPP_ID + '.desktop')).read_text()
        self.assertIn('Name=Work mail\n', desktop)
        self.assertIn('StartupWMClass=forynarch-webapp-' + WEBAPP_ID, desktop)
        rules = (self.data / 'config/hypr/webapp-titles.lua').read_text()
        self.assertIn('["hyprbars:title"]="Work mail"', rules)
        self.assertNotIn('https:', rules)
        self.assertEqual((self.profile / 'cookies').read_text(), 'account fixture')

    def test_unsafe_urls_and_oversized_images_are_rejected(self):
        for url in ['http://example.com', 'file:///tmp/icon', 'https://user:secret@example.com', 'https://example.com/\nwrong']:
            self.assertFalse(assets.https(url))
        oversized = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 9000, 9000) + b'\0' * 9
        self.assertIsNone(assets.image_type(oversized))
        self.assertIsNone(assets.image_type(b'<svg onload="bad"/>'))


if __name__ == '__main__':
    unittest.main()
