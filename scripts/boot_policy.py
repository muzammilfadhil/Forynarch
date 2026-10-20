#!/usr/bin/env python3
"""Apply graphical boot settings to staged files only."""
import argparse
from pathlib import Path
import re

PARAMETERS = ("quiet", "splash", "loglevel=3", "rd.systemd.show_status=auto", "systemd.show_status=auto")


def hooks(text):
    def replace(match):
        entries = match[1].split()
        entries = [entry for entry in entries if entry != "plymouth"]
        anchor = "kms" if "kms" in entries else "systemd" if "systemd" in entries else "udev"
        if anchor not in entries:
            raise ValueError("The initramfs requires a reviewed systemd or udev hook")
        entries.insert(entries.index(anchor) + 1, "plymouth")
        return "HOOKS=(" + " ".join(entries) + ")"
    return re.sub(r"^HOOKS=\(([^\n)]*)\)", replace, text, flags=re.M)


def parameters(line):
    if "accessibility=on" in line:
        return line
    for option in PARAMETERS:
        if option not in line.split():
            line = line.rstrip("\r\n") + " " + option + "\n"
    return line


def apply_root(root):
    root = Path(root).resolve()
    if root == Path("/") or not (root / "etc").is_dir():
        raise ValueError("A staged root is required")
    files = [root / "etc/mkinitcpio.conf", root / "usr/share/forynarch/mkinitcpio.conf.install"]
    files += list((root / "etc/mkinitcpio.conf.d").glob("*.conf"))
    for path in files:
        if path.is_file():
            path.write_text(hooks(path.read_text()))


def apply_profile(profile):
    profile = Path(profile).resolve()
    if not (profile / "profiledef.sh").is_file():
        raise ValueError("An Archiso staging profile is required")
    for directory in ("grub", "efiboot/loader/entries", "syslinux"):
        for path in (profile / directory).glob("*"):
            if path.suffix not in {".cfg", ".conf"} or not path.is_file():
                continue
            if path.is_symlink() or profile not in path.resolve().parents:
                raise ValueError("Boot configuration must stay inside the profile")
            lines = path.read_text().splitlines(keepends=True)
            text = "".join(parameters(line) if re.match(r"^\s*(linux(?:efi)?|options|APPEND)\s+", line) and "archisobasedir=" in line else line for line in lines)
            path.write_text(text.replace("Arch Linux install medium", "Forynarch Live"))
    loader = profile / "efiboot/loader/loader.conf"
    if loader.is_file() and not loader.is_symlink():
        loader.write_text(re.sub(r"^timeout\s+\d+", "timeout 3", loader.read_text(), flags=re.M))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("root", "profile"))
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    try:
        (apply_root if args.mode == "root" else apply_profile)(args.path)
    except ValueError as error:
        parser.exit(1, f"Boot policy: {error}\n")
