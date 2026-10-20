#!/usr/bin/env bash
set -euo pipefail
case "${1:-screenshots}" in
 screenshots) exec qs -c forynarch ipc call appearance openScreenshots ;;
 clipboard) exec qs -c forynarch ipc call appearance openClipboard ;;
 *) exit 2 ;;
esac
