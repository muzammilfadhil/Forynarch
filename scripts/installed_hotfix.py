#!/usr/bin/env python3
"""Install a bounded patch payload and retain a per-file restore manifest."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def relative(value):
    path = Path(value)
    if path.is_absolute() or '..' in path.parts or not path.parts:
        raise ValueError('Invalid patch destination')
    return path


def replace_file(source, destination, mode):
    destination.parent.mkdir(parents=True, exist_ok=True)
    pending = destination.with_name(destination.name + '.forynarch-pending')
    if pending.exists() or pending.is_symlink():
        raise ValueError('A pending patch file already exists: ' + str(pending))
    shutil.copyfile(source, pending)
    pending.chmod(mode)
    pending.replace(destination)


def apply(scope, bundle, patch_id):
    system = scope == 'system'
    if system != (os.geteuid() == 0):
        raise ValueError('System files require sudo; user files require the desktop user')
    base = Path('/') if system else Path.home()
    if not system and Path(os.environ.get('XDG_CONFIG_HOME', str(base/'.config'))) != base/'.config':
        raise ValueError('Use the standard ~/.config path for this patch')
    backup = (Path('/var/lib/forynarch/patches') if system else
              Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'forynarch/patches')/patch_id
    backup.mkdir(parents=True, mode=0o700, exist_ok=False)
    records = []

    def remember(path):
        rel = path.relative_to(base)
        if any(row['path'] == str(rel) for row in records):
            return
        exists = path.exists() or path.is_symlink()
        if exists:
            saved = backup/'files'/rel
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved, follow_symlinks=False)
        records.append({'path': str(rel), 'existed': exists})
        (backup/'restore.json').write_text(json.dumps(records, indent=2))

    payload = bundle/scope
    for source in sorted(payload.rglob('*')):
        if not source.is_file() or source.is_symlink():
            continue
        rel = relative(str(source.relative_to(payload)))
        if not system and rel.parts[0] != '.config':
            raise ValueError('User payload must stay in .config')
        destination = base/rel
        remember(destination)
        executable = str(rel).startswith('usr/local/bin/') or rel.suffix == '.so'
        replace_file(source, destination, 0o755 if executable else 0o644)

    if not system:
        config = Path(os.environ.get('XDG_CONFIG_HOME', str(base/'.config')))
        if patch_id.startswith('r588-'):
            remember(config/'forynarch/titlebars.json')
            remember(config/'hypr/titlebar-rules.lua')
        if (bundle/'windows-drives.json').is_file():
            remember(config/'forynarch/windows-drives.json')
            remember(config/'gtk-3.0/bookmarks')
        # The payload targets the standard .config tree shipped by R5.8.5.
        for name in (() if patch_id.startswith('r588-') else ('gtk-3.0', 'gtk-4.0')):
            path = config/name/'settings.ini'
            remember(path)
            text = path.read_text() if path.exists() else '[Settings]\n'
            setting = 'gtk-decoration-layout=:minimize,maximize,close'
            if re.search(r'^gtk-decoration-layout\s*=', text, flags=re.M):
                text = re.sub(r'^gtk-decoration-layout\s*=.*$', setting, text, flags=re.M)
            elif '[Settings]' in text:
                text = text.replace('[Settings]', '[Settings]\n' + setting, 1)
            else:
                text += '\n[Settings]\n' + setting + '\n'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        main = config/'hypr/hyprland.lua'
        if main.is_file():
            text = main.read_text()
            if 'titlebars.lua' not in text:
                remember(main)
                with main.open('a') as stream:
                    stream.write('\ndofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/titlebars.lua")\n')
        expected = (bundle/'hyprland-version.txt').read_text().strip()
        actual = subprocess.check_output(['pacman', '-Q', 'hyprland'], text=True).strip()
        if actual != expected:
            print('Titlebar binary was built for ' + expected + '; installed: ' + actual + '. Rebuild it before loading.', file=sys.stderr)
    shutil.copy2(__file__, backup/'restore.py')
    print(scope + ' files installed; restore with: ' + ('sudo ' if system else '') + 'python ' + str(backup/'restore.py') + ' restore ' + str(backup))


def restore(backup):
    system = str(backup).startswith('/var/lib/forynarch/patches/')
    if system != (os.geteuid() == 0):
        raise ValueError('Restore with the same user/privilege level as installation')
    base = Path('/') if system else Path.home()
    rows = json.loads((backup/'restore.json').read_text())
    for row in reversed(rows):
        rel = relative(row['path'])
        destination = base/rel
        if destination.is_symlink():
            destination.unlink()
        if row['existed']:
            saved = backup/'files'/rel
            if saved.is_symlink() and destination.exists():
                destination.unlink()
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(saved, destination, follow_symlinks=False)
        elif destination.exists():
            destination.unlink()
    print('Files restored. Restart your desktop session. Installed packages and browser profiles were retained.')


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == 'restore':
        restore(Path(sys.argv[2]).resolve())
    elif len(sys.argv) == 4 and sys.argv[1] in {'system', 'user'} and re.fullmatch(r'r58[678]-[0-9TZ]+', sys.argv[3]):
        apply(sys.argv[1], Path(sys.argv[2]).resolve(), sys.argv[3])
    else:
        sys.exit('Usage: patch.py system|user BUNDLE PATCH_ID; patch.py restore BACKUP')
