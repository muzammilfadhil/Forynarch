#!/usr/bin/env bash
set -euo pipefail
mode="${1:-restore}"
[[ $# -le 1 ]] || exit 2
if [[ "$mode" == restore ]]; then
    state="${XDG_STATE_HOME:-$HOME/.local/state}/forynarch/appearance.json"
    mode=on
    if [[ -f "$state" ]] && jq -e '.motion==false' "$state" >/dev/null; then mode=off;fi
fi
case "$mode" in
    on) profile=/usr/share/forynarch/motion.lua
        [[ -f "$profile" ]] || profile="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/config/hypr/motion.lua"
        [[ -f "$profile" ]] || { echo 'Motion profile is unavailable.' >&2;exit 1; }
        exec hyprctl eval "$(cat "$profile")" ;;
    off) exec hyprctl eval 'hl.config({animations={enabled=false}})' ;;
    *) echo 'Usage: forynarch-motion [on|off|restore]' >&2;exit 2 ;;
esac
