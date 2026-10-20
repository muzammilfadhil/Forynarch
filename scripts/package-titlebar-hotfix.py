#!/usr/bin/env python3
"""Build the R5.8.8 patch from reviewed titlebar binaries; no ISO or app packages."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--titlebars', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'out/patch/forynarch-r5.8.8')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'out'):
        raise ValueError('Patch output must remain under out/.')
    output.mkdir(parents=True, exist_ok=False)

    def copy(source, destination):
        path = output / destination
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, path)
        path.chmod(0o755 if destination.endswith('.sh') or destination.startswith('system/usr/local/bin/') or destination.endswith('.so') else 0o644)

    copy(ROOT / 'scripts/forynarch-titlebars.py', 'system/usr/local/bin/forynarch-titlebars')
    for name in ['titlebar-defaults.json']:
        copy(ROOT / 'config/forynarch' / name, 'system/usr/share/forynarch/' + name)
    copy(ROOT / 'config/hypr/titlebar-defaults.lua', 'system/usr/share/forynarch/titlebar-defaults.lua')
    for name in ['TitlebarSettings.qml', 'SettingsPanel.qml', 'SettingsCatalog.js']:
        for scope, prefix in [('system', 'etc/skel/'), ('user', '')]:
            copy(ROOT / 'config/quickshell/forynarch' / name, scope + '/' + prefix + '.config/quickshell/forynarch/' + name)
    for scope, prefix in [('system', 'etc/skel/'), ('user', '')]:
        copy(ROOT / 'config/hypr/titlebars.lua', scope + '/' + prefix + '.config/hypr/titlebars.lua')
    copy(args.titlebars / 'hyprbars-r588.so', 'system/usr/lib/forynarch/hyprbars.so')
    copy(args.titlebars / 'LICENSE', 'system/usr/share/licenses/forynarch/hyprbars-BSD-3-Clause.txt')
    copy(args.titlebars / 'upstream-commit.txt', 'system/usr/share/forynarch/hyprbars-commit.txt')
    copy(args.titlebars / 'hyprland-version.txt', 'hyprland-version.txt')
    copy(ROOT / 'scripts/apply-titlebar-hotfix.sh', 'apply.sh')
    copy(ROOT / 'scripts/installed_hotfix.py', 'patch.py')
    copy(ROOT / 'docs/installed-patch-r5.8.8.md', 'README.md')
    paths = sorted(p for p in output.rglob('*') if p.is_file())
    (output / 'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(output).as_posix() + '\n' for p in paths))
    archive = Path(str(output) + '.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        stream.add(output, arcname=output.name)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    Path(str(archive) + '.sha256').write_text(digest + '  ' + archive.name + '\n')
    print(str(archive), archive.stat().st_size, digest)


if __name__ == '__main__':
    main()
