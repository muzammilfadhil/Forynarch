import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


exporter = load('export-public-source')
inventory = load('release-package-inventory')


class PublicSource(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        (self.root / '.gitignore').write_text('out/\nprivate.key\n*.log\n', encoding='utf-8')
        (self.root / 'desktop.qml').write_text('public desktop source', encoding='utf-8')
        (self.root / 'private.key').write_text('synthetic private fixture', encoding='utf-8')
        subprocess.run(['git', 'add', '-f', 'private.key'], cwd=self.root, check=True)
        (self.root / 'personal.log').write_text('personal log fixture', encoding='utf-8')

    def test_excludes_ignored_tracked_files_and_history_and_hashes_source(self):
        output = self.root / 'out/public'
        with patch.object(exporter, 'ROOT', self.root):
            exporter.export(output)
        self.assertFalse((output / 'private.key').exists())
        self.assertFalse((output / 'personal.log').exists())
        self.assertFalse((output / '.git').exists())
        manifest = json.loads((output / 'SOURCE-MANIFEST.json').read_text())['files']
        entry = next(item for item in manifest if item['file'] == 'desktop.qml')
        self.assertEqual(entry['sha256'], hashlib.sha256(b'public desktop source').hexdigest())
        with zipfile.ZipFile(output.with_suffix('.zip')) as archive:
            self.assertEqual(set(archive.namelist()), {'.gitignore', 'desktop.qml', 'SOURCE-MANIFEST.json'})

    def test_refuses_paths_outside_generated_directory(self):
        with patch.object(exporter, 'ROOT', self.root), self.assertRaises(ValueError):
            exporter.export(self.root / 'public')
        self.assertFalse((self.root / 'public').exists())

    def test_dotted_output_keeps_release_version_in_archive_name(self):
        output = self.root / 'out/public-r5.9.0'
        with patch.object(exporter, 'ROOT', self.root):
            exporter.export(output)
        self.assertTrue(Path(str(output) + '.zip').is_file())
        self.assertFalse((output.parent / 'public-r5.9.zip').exists())

    def test_refuses_existing_directory_without_overwriting(self):
        output = self.root / 'out/public'
        output.mkdir(parents=True)
        marker = output / 'keep'
        marker.write_text('keep')
        with patch.object(exporter, 'ROOT', self.root), self.assertRaises(ValueError):
            exporter.export(output)
        self.assertEqual(marker.read_text(), 'keep')


class PackageInventory(unittest.TestCase):
    def test_retains_exact_versions_and_multiple_license_fields(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            record = root / 'var/lib/pacman/local/fixture-1/desc'
            record.parent.mkdir(parents=True)
            record.write_text('%NAME%\nfixture\n\n%VERSION%\n2:1.0-3\n\n%BASE%\nfixture-base\n\n%LICENSE%\nMIT\nGPL-3.0-or-later\n\n%URL%\nhttps://example.com/source\n', encoding='utf-8')
            package = inventory.inventory(root)['packages'][0]
        self.assertEqual(package['version'], '2:1.0-3')
        self.assertEqual(package['licenses'], ['MIT', 'GPL-3.0-or-later'])
        self.assertIn('requires release-specific review', package['corresponding_source_status'])

    def test_rejects_missing_database(self):
        with tempfile.TemporaryDirectory() as temporary, self.assertRaises(ValueError):
            inventory.inventory(temporary)
