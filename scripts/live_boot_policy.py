#!/usr/bin/env python3
"""Keep local Live USB boots on their medium unless copying to RAM is chosen."""
import argparse
from pathlib import Path
import re

COMMAND = re.compile(r"^\s*(?:linux(?:efi)?|options|APPEND)\s+")


def apply(profile):
    profile = Path(profile).resolve()
    if not (profile / "profiledef.sh").is_file():
        raise ValueError("An Archiso staging profile is required")
    changes = []
    matches = 0
    for directory in ("grub", "efiboot/loader/entries", "syslinux"):
        for path in sorted((profile / directory).glob("*")):
            if path.suffix not in {".cfg", ".conf"} or not path.is_file():
                continue
            if path.is_symlink() or profile not in path.resolve().parents:
                raise ValueError("Boot configuration must stay inside the staging profile")
            original = path.read_text(encoding="utf-8")
            result = []
            for line in original.splitlines(keepends=True):
                if COMMAND.match(line) and "archisobasedir=" in line and not any(token in line for token in ("archiso_nbd_srv=", "archiso_nfs_srv=", "archiso_http_srv=")):
                    matches += 1
                    if not re.search(r"(?:^|\s)copytoram(?:=\S*)?(?=\s|$)", line):
                        line = line.rstrip("\r\n") + " copytoram=n\n"
                result.append(line)
            changed = "".join(result)
            if changed != original:
                changes.append((path, changed))
    if matches == 0:
        raise ValueError("No supported local Archiso boot entries found; review the upstream profile")
    for path, text in changes:
        path.write_text(text, encoding="utf-8")
    return matches, len(changes)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", type=Path)
    args = parser.parse_args()
    try:
        entries, files = apply(args.profile)
    except ValueError as error:
        parser.exit(1, f"Live boot policy: {error}\n")
    print(f"Live boot policy: {entries} local entries checked; {files} files updated. Explicit copy-to-RAM choices preserved.")
