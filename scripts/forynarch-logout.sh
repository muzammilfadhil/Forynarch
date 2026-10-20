#!/usr/bin/env bash
set -euo pipefail
session="${XDG_SESSION_ID:-}"
[[ "$session" =~ ^[a-zA-Z0-9]+$ ]] || { notify-send 'Log out' 'The current login session could not be identified.';exit 1; }
owner="$(loginctl show-session "$session" -p User --value)"
[[ "$owner" == "$(id -u)" ]] || exit 1
# Let SDDM's session helper finish before logind removes remaining user processes.
exec hyprctl dispatch 'hl.dsp.exit()'
