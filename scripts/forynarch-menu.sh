#!/usr/bin/env bash
set -euo pipefail
choice="$(printf '%s\n' 'Applications' 'Files' 'Terminal' 'Network' 'Keyboard shortcuts' 'Session' |
  fuzzel --dmenu --prompt='Forynarch  ')" || exit 0
case "$choice" in
  Applications) exec fuzzel ;;
  Files) exec forynarch-files ;;
  Terminal) exec forynarch-terminal ;;
  Network) exec forynarch-terminal --title=Network nmtui ;;
  'Keyboard shortcuts') exec forynarch-terminal --title='Forynarch shortcuts' forynarch-shortcuts ;;
  Session) exec forynarch-power ;;
esac
