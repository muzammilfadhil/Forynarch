"""Declare local executable modes that Archiso otherwise resets to 0644."""
import argparse
from pathlib import Path
import re

START = "# Forynarch local executable permissions\n"
END = "# End Forynarch local executable permissions\n"


def apply(profile):
    profile = Path(profile)
    paths = []
    for directory in ("usr/local/bin", "usr/local/libexec"):
        for path in (profile / "airootfs" / directory).glob("*"):
            if path.is_symlink() or not path.is_file() or not path.stat().st_mode & 0o111:
                continue
            relative = "/" + path.relative_to(profile / "airootfs").as_posix()
            if not re.fullmatch(r"/usr/local/(bin|libexec)/[A-Za-z0-9_.-]+", relative):
                raise ValueError("Unexpected local executable path")
            paths.append(relative)
    definition = profile / "profiledef.sh"
    source = definition.read_text(encoding="utf-8")
    if START in source:
        before, remainder = source.split(START, 1)
        _, after = remainder.split(END, 1)
        source = before + after
    block = START + "".join(f'file_permissions+=( ["{path}"]="0:0:755" )\n' for path in sorted(paths)) + END
    definition.write_text(source.rstrip() + "\n" + block, encoding="utf-8", newline="\n")
    return len(paths)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=Path)
    args = parser.parse_args()
    print(f"Declared {apply(args.profile)} local executable permissions")
