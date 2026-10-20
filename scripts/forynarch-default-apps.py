#!/usr/bin/env python3
"""Inspect and change the current user's default applications."""
import argparse
import json
import subprocess
import sys
from forynarch_defaults import choose, status, terminal_id

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "set", "terminal"])
    parser.add_argument("category", nargs="?")
    parser.add_argument("application", nargs="?")
    args = parser.parse_args()
    if args.action == "terminal":
        print(json.dumps({"terminal": terminal_id()}))
        return
    if args.action == "set":
        choose(args.category, args.application)
    print(json.dumps(status()))

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
