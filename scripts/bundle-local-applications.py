#!/usr/bin/env python3
"""Bundle reviewed optional binaries separately from the installed core rootfs."""
import json
from pathlib import Path
import shutil
import sys

from local_applications import verified_packages


def bundle(source, destination):
    source, destination = Path(source), Path(destination)
    manifest = json.loads((source / "packages/local-applications.json").read_text())
    available = {}
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "optional").mkdir(exist_ok=True)
    for name, record in manifest["packages"].items():
        path = source / "out/optional" / record["filename"]
        if not path.is_file():
            print(f"Optional {name} binary is absent; its installer choice will be unavailable.", file=sys.stderr)
            continue
        shutil.copyfile(path, destination / "optional" / record["filename"])
        available[name] = record
    manifest["packages"] = available
    (destination / "local-applications.json").write_text(json.dumps(manifest, indent=2) + "\n")
    plan = {"selected_group_ids": list(available), "explicit_optional_packages": list(available)}
    verified_packages(destination, plan)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: bundle-local-applications.py SOURCE BUNDLE")
    bundle(*sys.argv[1:])
