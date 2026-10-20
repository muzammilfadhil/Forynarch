#!/usr/bin/env python3
"""Fetch bounded website icons and keep owned web-app launchers/title rules in sync."""
import argparse
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import time
from urllib.parse import urljoin, urlsplit

UUID = re.compile(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}')
BASE = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'forynarch/webapps'
APPLICATIONS = BASE.parents[1] / 'applications'
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))


def https(url):
    if not isinstance(url, str):
        return False
    try:
        value = urlsplit(url)
        return len(url) <= 2048 and value.scheme == 'https' and bool(value.hostname) and not value.username and not value.password and not re.search(r'[\x00-\x20\x7f]', url)
    except ValueError:
        return False


def download(url, limit, seconds):
    if not https(url) or seconds <= 0:
        return b''
    command = ['curl', '--proto', '=https', '--proto-redir', '=https', '--location', '--max-redirs', '3',
               '--silent', '--fail', '--max-time', str(min(3, seconds)), '--max-filesize', str(limit), url]
    try:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as process:
            result = process.stdout.read(limit + 1)
            if len(result) > limit:
                process.kill()
            code = process.wait(timeout=4)
            return result if code == 0 and len(result) <= limit else b''
    except (OSError, subprocess.TimeoutExpired):
        return b''


class Icons(HTMLParser):
    def __init__(self, url):
        super().__init__()
        self.url, self.links = url, []
        self.in_head = True

    def handle_starttag(self, tag, attrs):
        if tag == 'body':
            self.in_head = False
        values = dict(attrs)
        rel = (values.get('rel') or '').lower().split()
        if self.in_head and tag == 'link' and ('icon' in rel or 'apple-touch-icon' in rel):
            url = urljoin(self.url, values.get('href') or '')
            if https(url) and url not in self.links:
                self.links.append(url)


def image_type(data):
    if len(data) >= 33 and data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR':
        width, height = struct.unpack('>II', data[16:24])
        return 'png' if 0 < width <= 1024 and 0 < height <= 1024 else None
    if len(data) >= 22 and data[:4] == b'\0\0\1\0':
        count = struct.unpack('<H', data[4:6])[0]
        if not 0 < count <= 64 or len(data) < 6 + count * 16:
            return None
        for index in range(count):
            entry = data[6 + index * 16:22 + index * 16]
            size, offset = struct.unpack('<II', entry[8:16])
            if not size or offset < 6 + count * 16 or offset + size > len(data):
                return None
            payload = data[offset:offset + size]
            if payload.startswith(b'\x89PNG'):
                if image_type(payload) != 'png':
                    return None
            elif len(payload) < 40 or struct.unpack('<I', payload[:4])[0] != 40:
                return None
            else:
                width, height = struct.unpack('<ii', payload[4:12])
                if not 0 < width <= 256 or not 0 < height <= 512:
                    return None
        return 'ico'
    return None


def write(path, content):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.exists() and not path.is_symlink() and path.read_bytes() == content:
        return False
    fd, temporary = tempfile.mkstemp(prefix='.webapp-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return True


def metadata(path):
    if path.is_symlink() or not UUID.fullmatch(path.stem) or path.stat().st_size > 8192:
        raise ValueError('Invalid web app metadata.')
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or not isinstance(value.get('name'), str) or not 0 < len(value['name']) <= 80 or re.search(r'[\x00-\x1f\x7f\\]', value['name']):
        raise ValueError('Invalid web app name.')
    return value


def refresh(path, deadline):
    value = metadata(path)
    if not value.get('active') or not https(value.get('url', '')):
        return
    profile = BASE / path.stem
    if profile.is_symlink():
        raise ValueError('A web app profile must be a local directory.')
    parser = Icons(value['url'])
    parser.feed(download(value['url'], 524288, deadline - time.monotonic()).decode('utf-8', errors='replace'))
    candidates = ([value['iconUrl']] if https(value.get('iconUrl', '')) else []) + parser.links
    candidates += [urljoin(value['url'], '/favicon.ico'), urljoin(value['url'], '/apple-touch-icon.png')]
    for url in list(dict.fromkeys(candidates))[:4]:
        if time.monotonic() >= deadline:
            break
        data = download(url, 1048576, deadline - time.monotonic())
        kind = image_type(data)
        if kind:
            icon = profile / ('icon.' + kind)
            write(icon, data)
            value['icon'] = str(icon)
            write(path, (json.dumps(value, ensure_ascii=False) + '\n').encode())
            break


def sync():
    rules = ['-- Generated from owned web-app names; browser profiles are retained.']
    for path in sorted(BASE.glob('*.json')):
        try:
            value = metadata(path)
        except (OSError, ValueError, TypeError):
            continue
        key, name = path.stem, value['name']
        active = value.get('active') is True
        rules.append('hl.window_rule({name="forynarch-webapp-' + key + '",match={class=".*forynarch-webapp-' + key + '.*"},["hyprbars:title"]=' + json.dumps(name, ensure_ascii=False) + ',enabled=' + str(active).lower() + '})')
        if not active:
            continue
        icon = value.get('icon', 'applications-internet')
        if not isinstance(icon, str) or re.search(r'[\x00-\x1f\x7f]', icon):
            icon = 'applications-internet'
        if icon.startswith('/'):
            if not Path(icon).resolve().is_relative_to((BASE / key).resolve()) or not Path(icon).is_file():
                icon = 'applications-internet'
        elif not re.fullmatch(r'[A-Za-z0-9_.-]+', icon):
            icon = 'applications-internet'
        text = ('[Desktop Entry]\nType=Application\nName=' + name + '\nComment=Web app with a separate account profile\nExec=forynarch-webapps launch ' + key + '\nIcon=' + icon + '\nTerminal=false\nCategories=Network;\nStartupNotify=true\nStartupWMClass=forynarch-webapp-' + key + '\n')
        write(APPLICATIONS / ('forynarch-webapp-' + key + '.desktop'), text.encode())
    path = CONFIG / 'hypr/webapp-titles.lua'
    changed = write(path, ('\n'.join(rules) + '\n').encode())
    if changed and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        # Existing plugin mappings remain loaded until logout; old versions skip these rules.
        literal = json.dumps(str(path), ensure_ascii=False)
        try:
            subprocess.run(['hyprctl', 'eval', 'if _G.forynarch_webapp_titles then dofile(' + literal + ') end'], capture_output=True, timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['refresh', 'refresh-missing', 'sync'])
    parser.add_argument('id', nargs='?')
    args = parser.parse_args()
    if args.action == 'refresh':
        if not args.id or not UUID.fullmatch(args.id):
            parser.error('A web app ID is required.')
        refresh(BASE / (args.id + '.json'), time.monotonic() + 10)
    elif args.action == 'refresh-missing':
        deadline = time.monotonic() + 30
        for path in sorted(BASE.glob('*.json'))[:12]:
            if time.monotonic() >= deadline:
                break
            try:
                value = metadata(path)
                icon = value.get('icon', '')
                if not isinstance(icon, str) or not icon.startswith('/') or not Path(icon).is_file():
                    refresh(path, deadline)
            except (OSError, ValueError, TypeError):
                continue
    sync()


if __name__ == '__main__':
    main()
