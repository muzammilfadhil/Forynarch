"""Generate the shipped emoji catalogue from Unicode 17.0 emoji-test.txt."""
import argparse
import json
import re
from pathlib import Path


def catalogue(source):
    group = ""
    rows = []
    for line in source.splitlines():
        if line.startswith("# group: "):
            group = line.removeprefix("# group: ")
        match = re.match(r"^([0-9A-F ]+)\s*; fully-qualified\s*#\s*\S+\s+E[\d.]+\s+(.+)$", line)
        if match:
            value = "".join(chr(int(cp, 16)) for cp in match[1].split())
            rows.append(dict(value=value, name=match[2], group=group))
    if len(rows) < 3000:
        raise ValueError("Incomplete Unicode emoji catalogue")
    return rows


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rows = catalogue(args.source.read_text(encoding="utf-8"))
    args.output.write_text('.pragma library\n// Unicode 17.0; Unicode-3.0. See licenses/Unicode.txt.\nvar rows = ' + json.dumps(rows, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8", newline="\n")
    print(f"Generated {len(rows)} emoji")
