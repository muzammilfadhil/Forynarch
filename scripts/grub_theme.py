#!/usr/bin/env python3
"""Stage the pinned Particle Circle theme; never install a running bootloader."""
import argparse
from pathlib import Path
import re
import shutil

SOURCE = Path(__file__).resolve().parents[1]
THEME = SOURCE / 'assets/grub/particle-circle-window'
NAME = 'forynarch-particle'
BEGIN = '# BEGIN FORYNARCH PARTICLE THEME'
END = '# END FORYNARCH PARTICLE THEME'

def staged(path, marker):
    original = Path(path).absolute()
    root = original.resolve()
    if root == Path(root.anchor) or original != root or not (root / marker).exists():
        raise ValueError('A real staging directory with the required marker is needed.')
    return root

def safe_path(root, relative):
    result = root / relative
    if root not in result.resolve().parents or any(parent.is_symlink() for parent in (result, *result.parents) if parent != root):
        raise ValueError('Staged boot files must not traverse a symbolic link.')
    return result

def copy_theme(destination):
    destination.mkdir(parents=True, exist_ok=True)
    for path in THEME.rglob('*'):
        if path.is_symlink():
            raise ValueError('Theme assets must not be symbolic links.')
        if path.is_file():
            target = safe_path(destination, path.relative_to(THEME))
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    shutil.copyfile(SOURCE / 'licenses/Particle-circle-GPL-3.0.txt', destination / 'COPYING')
    shutil.copyfile(SOURCE / 'licenses/Unifont-OFL-1.1.txt', destination / 'Unifont-OFL-1.1.txt')

def apply_root(path):
    root = staged(path, 'etc')
    copy_theme(safe_path(root, 'usr/share/grub/themes/' + NAME))
    defaults = safe_path(root, 'etc/default/grub')
    defaults.parent.mkdir(parents=True, exist_ok=True)
    defaults.write_text((SOURCE / 'config/grub/defaults').read_text(), encoding='utf-8')
    diagnostic = safe_path(root, 'etc/grub.d/41_forynarch_diagnostic')
    diagnostic.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / 'config/grub/41_forynarch_diagnostic', diagnostic)
    diagnostic.chmod(0o755)

def apply_profile(path):
    root = staged(path, 'profiledef.sh')
    definition = safe_path(root, 'profiledef.sh')
    text = definition.read_text()
    modes = re.search(r'bootmodes=\((.*?)\)', text, re.S)
    if not modes or not re.fullmatch(r"[\s'\"a-z0-9.\-]+", modes[1]):
        raise ValueError('Review this Archiso version before changing its boot modes.')
    choices = re.findall(r"['\"]([^'\"]+)['\"]", modes[1])
    if not choices or set(choices) - {'bios.syslinux', 'uefi.systemd-boot', 'uefi.grub'}:
        raise ValueError('Unsupported Archiso boot-mode syntax.')
    choices = list(dict.fromkeys('uefi.grub' if value == 'uefi.systemd-boot' else value for value in choices))
    if 'uefi.grub' not in choices:
        raise ValueError('The profile needs a reviewed UEFI boot mode.')
    config = safe_path(root, 'grub/grub.cfg')
    content = config.read_text()
    if '%INSTALL_DIR%' not in content or 'archlinux' not in content:
        raise ValueError('Expected the reviewed Archiso releng GRUB configuration.')
    content = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END) + r'\n?', '', content, flags=re.S)
    block = f'''{BEGIN}
set gfxmode=1920x1080,1600x900,1366x768,1280x800,1024x768,auto
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
insmod jpeg
if loadfont "/boot/grub/themes/{NAME}/unifont-16.pf2"; then
    if terminal_output gfxterm; then
        set theme="/boot/grub/themes/{NAME}/theme.txt"
        export theme
    else
        terminal_output console
    fi
fi
{END}
'''
    lines = content.splitlines(keepends=True)
    first_menu = next((index for index,line in enumerate(lines) if line.startswith('menuentry ')), None)
    if first_menu is None:
        raise ValueError('The GRUB profile has no boot entries.')
    lines.insert(first_menu, block)
    for index, line in enumerate(lines):
        if line.startswith('menuentry ') and "--id 'archlinux'" in line:
            line = re.sub(r'^menuentry "[^"]*"', 'menuentry "Try or install Forynarch"', line)
        elif line.startswith('menuentry ') and "--id 'archlinux-accessibility'" in line:
            line = re.sub(r'^menuentry "[^"]*"', 'menuentry "Forynarch screen reader"', line)
        lines[index] = line.replace('--class arch ', '--class forynarch ')
    content = re.sub(r'^(?:set\s+)?timeout=\d+', 'set timeout=5', ''.join(lines), flags=re.M)
    copy_theme(safe_path(root, 'grub/themes/' + NAME))
    definition.write_text(text[:modes.start()] + "bootmodes=(" + ' '.join(repr(value) for value in choices) + ")" + text[modes.end():])
    config.write_text(content)
    generated = root / 'airootfs/usr/share/grub/themes' / NAME / 'icons/forynarch.png'
    if generated.is_file() and not generated.is_symlink():
        shutil.copyfile(generated, root / 'grub/themes' / NAME / 'icons/forynarch.png')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('root','profile'))
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    try:
        (apply_root if args.mode == 'root' else apply_profile)(args.path)
    except ValueError as error:
        parser.exit(1, f'GRUB theme: {error}\n')
