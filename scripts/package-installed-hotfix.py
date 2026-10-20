#!/usr/bin/env python3
"""Package the R5.8.6 patch; binary build inputs stay outside Git."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--titlebars', required=True, type=Path)
    parser.add_argument('--drive-map', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT/'out/patch/forynarch-r5.8.6')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT/'out'):
        raise ValueError('Patch output must stay under workspace out/')
    output.mkdir(parents=True, exist_ok=False)

    def copy(source, destination):
        target = output/destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o755 if destination.startswith('system/usr/local/bin/') else 0o644)

    helpers = {'forynarch-drives.sh':'forynarch-drives',
               'forynarch-audio-start.sh':'forynarch-audio-start',
               'forynarch-session-start.sh':'forynarch-session-start',
               'forynarch-hotkey.sh':'forynarch-hotkey', 'forynarch-lock.sh':'forynarch-lock'}
    for source, name in helpers.items():
        copy(ROOT/'scripts'/source, 'system/usr/local/bin/'+name)
    copy(ROOT/'scripts/storage-model.jq', 'system/usr/share/forynarch/storage-model.jq')
    copy(ROOT/'config/hypr/hyprlock.conf', 'system/usr/share/forynarch/hyprlock.conf')
    for name in ('DrivesPanel.qml', 'MediaModel.qml'):
        for scope, base in (('system','etc/skel/'), ('user','')):
            copy(ROOT/'config/quickshell/forynarch'/name, scope+'/'+base+'.config/quickshell/forynarch/'+name)
    for name in ('titlebars.lua','hyprlock.conf'):
        for scope, base in (('system','etc/skel/'), ('user','')):
            copy(ROOT/'config/hypr'/name, scope+'/'+base+'.config/hypr/'+name)
    for name in ('gtk-3.0','gtk-4.0'):
        copy(ROOT/'config'/name/'settings.ini','system/etc/skel/.config/'+name+'/settings.ini')
    copy(args.titlebars/'hyprbars.so', 'system/usr/lib/forynarch/hyprbars.so')
    copy(args.titlebars/'LICENSE', 'system/usr/share/licenses/forynarch/hyprbars-BSD-3-Clause.txt')
    copy(args.titlebars/'upstream-commit.txt', 'system/usr/share/forynarch/hyprbars-commit.txt')
    copy(args.titlebars/'hyprland-version.txt','hyprland-version.txt')
    copy(args.titlebars/'lock-logo.png','system/usr/share/forynarch/branding/logo.png')
    copy(ROOT/'scripts/apply-installed-hotfix.sh','apply.sh')
    copy(ROOT/'scripts/installed_hotfix.py','patch.py')
    copy(ROOT/'docs/installed-patch-r5.8.6.md','README.md')
    if args.drive_map:
        copy(args.drive_map,'windows-drives.json')
    files = sorted(p for p in output.rglob('*') if p.is_file())
    (output/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(output).as_posix()+'\n' for p in files))
    archive = Path(str(output)+'.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        stream.add(output, arcname=output.name)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    Path(str(archive)+'.sha256').write_text(digest+'  '+archive.name+'\n')
    print(str(archive), archive.stat().st_size, digest)


if __name__ == '__main__':
    main()
