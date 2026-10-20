#!/usr/bin/env python3
"""Export reviewable source without Git history or ignored local material."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def export(output):
    output = Path(output).absolute()
    generated = (ROOT / 'out').resolve()
    if generated not in output.resolve().parents or output.exists():
        raise ValueError('Choose a new directory inside the repository out/ directory.')
    archive = Path(str(output) + '.zip')
    if archive.exists():
        raise ValueError('Archive already exists; choose another output name.')
    names = set(subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=ROOT).decode('utf-8').strip('\0').split('\0')) - {''}
    ignored = subprocess.run(
        ['git', 'check-ignore', '--no-index', '-z', '--stdin'], cwd=ROOT,
        input=('\0'.join(sorted(names)) + '\0').encode('utf-8'),
        stdout=subprocess.PIPE, check=False)
    if ignored.returncode not in (0, 1):
        raise RuntimeError('Could not evaluate ignore rules.')
    names -= set(ignored.stdout.decode('utf-8').strip('\0').split('\0'))
    files = []
    for name in sorted(names):
        relative = Path(name)
        path = ROOT / relative
        if path.is_symlink() or relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Unsupported source path: ' + name)
        if not path.is_file():
            continue
        if ROOT not in path.resolve().parents:
            raise ValueError('Source path escapes repository: ' + name)
        files.append((name, path))
    output.mkdir(parents=True)
    manifest = []
    for name, source in files:
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        manifest.append({'file': name, 'bytes': target.stat().st_size,
                         'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (output / 'SOURCE-MANIFEST.json').write_text(
        json.dumps({'format': 1, 'files': manifest}, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(output.rglob('*')):
            if path.is_file():
                info = zipfile.ZipInfo(path.relative_to(output).as_posix())
                info.compress_type = zipfile.ZIP_DEFLATED
                executable = path.suffix in ('.sh', '.py') or path.parent.name == 'grub.d'
                info.external_attr = (0o100755 if executable else 0o100644) << 16
                bundle.writestr(info, path.read_bytes())
    print(json.dumps({'files': len(manifest), 'archive': str(archive),
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    arguments = parser.parse_args()
    try:
        export(arguments.output)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, str(error) + '\n')
