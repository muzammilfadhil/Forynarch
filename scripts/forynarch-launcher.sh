#!/usr/bin/env bash
# Use the Glass launcher when its IPC is ready; retain the classic fallback.
set -euo pipefail
if command -v qs >/dev/null &&
   qs -c forynarch ipc call appearance openLauncher >/dev/null 2>&1; then
  exit 0
fi
exec fuzzel "$@"
