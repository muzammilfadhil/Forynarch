#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  focus-return)
    client="$(hyprctl -j activewindow)" || exit 1
    window_address="$(jq -er '.address|select(type=="string" and test("^0x[a-fA-F0-9]+$"))' <<< "$client")" || exit 1
    monitor="$(hyprctl -j monitors | jq -er 'first(.[]|select(.focused))|.id')" || exit 1
    [[ "$(jq -r .monitor <<< "$client")" == "$monitor" ]] || exit 1
    exec hyprctl dispatch "hl.dsp.focus({window=\"address:$window_address\"})" >/dev/null ;;
  media)
    [[ $# == 2 && "$2" =~ ^(next|previous|toggle)$ ]] || exit 2
    if command -v qs >/dev/null && qs -c forynarch ipc call appearance media "$2" >/dev/null 2>&1; then exit 0; fi
    command -v playerctl >/dev/null || exit 0
    operation="$2"; [[ "$operation" != toggle ]] || operation=play-pause
    exec playerctl "$operation" ;;
  layout-toggle)
    exec forynarch-window-control toggle-all ;;
  zoom|zoom-reset)
    factor=1
    if [[ "$1" == zoom ]]; then factor="$(hyprctl -j getoption cursor:zoom_factor | jq -r '(.float+0.5) | if .>4 then 4 else . end')"; fi
    [[ "$factor" =~ ^[1-4]([.][0-9]+)?$ ]] || exit 1
    exec hyprctl eval "hl.config({cursor={zoom_factor=$factor}})" ;;
  lock)
    if [[ -d /run/archiso ]]; then exec notify-send 'Lock unavailable' 'The disposable Live user has no password. Installed sessions support locking.'; fi
    exec forynarch-lock ;;
  screenshot) exec forynarch-capture region ;;
  *) exit 2 ;;
esac
