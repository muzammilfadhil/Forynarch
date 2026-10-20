#!/usr/bin/env python3
"""Transfer source only; omit generated caches, images and private material."""
import argparse
import zipfile
from pathlib import Path

DIRECTORIES = ("scripts", "docs", "packages", "config", "assets", "tests", "native", "licenses")
ROOT_FILES = ("README.md", "AGENTS.md", ".gitignore", ".gitattributes")
EXCLUDED_SUFFIXES = {".pyc", ".iso", ".vdi", ".qcow2", ".pem", ".key", ".log", ".tmp", ".qsb"}


def archive_source(root, output):
    root = Path(root).resolve()
    paths = [root / name for name in ROOT_FILES]
    for name in DIRECTORIES:
        paths.extend((root / name).rglob("*"))
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(paths):
            relative = path.relative_to(root)
            if relative.parts[0] == "native" and path.suffix not in {".cpp", ".h", ".hpp", ".pro"}:
                continue
            if (not path.is_file() or path.is_symlink() or "__pycache__" in relative.parts
                    or path.suffix.lower() in EXCLUDED_SUFFIXES or path.name in {"id_rsa", "id_ed25519"}
                    or path.name == ".env" or path.name.startswith(".env.")):
                continue
            if any(parent.is_symlink() for parent in path.parents if parent != root):
                continue
            archive.write(path, relative.as_posix())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    archive_source(args.root, args.output)
