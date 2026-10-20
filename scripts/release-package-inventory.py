#!/usr/bin/env python3
"""Read staged pacman metadata without running commands or modifying the root."""
import argparse
import json
from pathlib import Path
from urllib.parse import quote


def inventory(root):
    database = Path(root) / 'var/lib/pacman/local'
    if not database.is_dir():
        raise ValueError('A staged root with a pacman local database is required.')
    packages = []
    for description in sorted(database.glob('*/desc')):
        fields = {}
        key = None
        for line in description.read_text(encoding='utf-8').splitlines():
            if line.startswith('%') and line.endswith('%'):
                key = line.strip('%')
                fields[key] = []
            elif key and line:
                fields[key].append(line)
        name = fields.get('NAME', [''])[0]
        base = fields.get('BASE', [name])[0]
        packages.append({'name': name, 'version': fields.get('VERSION', [''])[0],
                         'architecture': fields.get('ARCH', [''])[0],
                         'licenses': fields.get('LICENSE', []),
                         'upstream_url': fields.get('URL', [''])[0],
                         'package_base': base,
                         'arch_recipe_candidate': 'https://gitlab.archlinux.org/archlinux/packaging/packages/' + quote(base, safe=''),
                         'corresponding_source_status': 'requires release-specific review'})
    if not packages:
        raise ValueError('The staged package database is empty.')
    return {'format': 1, 'note': 'Metadata and recipe pointers are not an archive of corresponding sources. Verify exact versions and applicable distribution obligations before binary publication.',
            'packages': sorted(packages, key=lambda package: package['name'])}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    try:
        payload = inventory(args.root)
        Path(args.output).write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
        print(str(len(payload['packages'])) + ' package records written.')
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + '\n')
