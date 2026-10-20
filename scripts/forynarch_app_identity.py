"""Resolve owned web-app profiles and Mudil without scanning desktop catalogs."""
import json
import os
from pathlib import Path
import re

UUID = r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'


def identity(client):
    app = str(client.get('class', ''))
    if re.fullmatch(r'(me\.muzammilfadhil\.mudilmusic|com\.example\.muzo|mudilmusic|mudil[ -]?music|muzo)(\.desktop)?', app, re.I):
        logo = Path('/usr/share/icons/hicolor/512x512/apps/mudilmusic.png')
        return {'displayName': 'Mudil Music', 'icon': str(logo) if logo.is_file() else 'mudilmusic'}
    match = re.search(r'forynarch-webapp-(' + UUID + r')', app + ' ' + str(client.get('initialClass', '')))
    if not match and re.search(r'chrome|chromium|vivaldi|firefox|zen', app, re.I):
        try:
            proc = Path('/proc') / str(int(client.get('pid', 0)))
            if proc.stat().st_uid == os.getuid():
                command = (proc / 'cmdline').read_bytes()[:8192].decode(errors='replace')
                match = re.search(r'forynarch(?:/webapps|-webapps)/(' + UUID + r')', command)
        except (OSError, ValueError):
            pass
    if not match:
        return {}
    key = match[1]
    base = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'forynarch/webapps'
    metadata = base / (key + '.json')
    try:
        if metadata.is_symlink() or metadata.stat().st_size > 8192:
            return {}
        value = json.loads(metadata.read_text())
        name = value['name']
        if not value.get('active') or not isinstance(name, str) or not 0 < len(name) <= 80 or re.search(r'[\x00-\x1f\x7f]', name):
            return {}
        icon = value.get('icon', '')
        if not isinstance(icon, str):
            icon = ''
        if Path(icon).is_absolute():
            path = Path(icon).resolve()
            if not path.is_relative_to((base / key).resolve()) or not path.is_file():
                icon = ''
        elif not re.fullmatch(r'[A-Za-z0-9_.-]+', icon):
            icon = ''
        return {'app': 'forynarch-webapp-' + key, 'displayName': name, 'title': name, 'icon': icon or 'applications-internet'}
    except (OSError, ValueError, KeyError, TypeError):
        return {}
