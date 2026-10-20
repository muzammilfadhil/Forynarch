#!/usr/bin/env bash
set -euo pipefail
if command -v qs >/dev/null && qs -c forynarch ipc call appearance openPage Shortcuts >/dev/null 2>&1; then exit 0; fi
guide=/usr/share/forynarch/hotkeys.txt
[[ -f "$guide" ]] || guide="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../config/forynarch" && pwd)/hotkeys.txt"
cat -- "$guide"
printf '\nPress Enter to close the guide.\n'
read -r _
