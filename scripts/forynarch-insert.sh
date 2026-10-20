#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && ( "$1" == copy || "$1" == paste ) ]] || exit 2
value="$(head -c 4096)"
[[ -n "$value" ]] || exit 2
printf '%s' "$value" | wl-copy --type 'text/plain;charset=utf-8'
if [[ "$1" == paste ]]; then
    target="$(hyprctl -j activewindow)" || exit 0
    address="$(jq -er '.address|select(type=="string" and test("^0x[a-fA-F0-9]+$"))' <<< "$target")" || exit 0
    sleep 0.18
    [[ "$(hyprctl -j activewindow | jq -r '.address//""')" == "$address" ]] || exit 0
    status="$(qs -c forynarch ipc call appearance status 2>/dev/null)" || status='{}'
    if jq -e '.settingsOpen or .controlOpen or .launcherOpen or .drivesOpen or .emojiOpen or .webAppsOpen or .widgetEditing' <<< "$status" >/dev/null;then exit 0;fi
    if ! forynarch-hotkey focus-return >/dev/null;then exit 0;fi
    app="$(jq -r '.class//""' <<< "$target")"
    mods=CTRL
    case "${app,,}" in foot*|kitty|alacritty|*wezterm*|*ghostty*|*konsole*|*gnome-terminal*|*org.gnome.terminal*) mods='CTRL SHIFT';;esac
    hyprctl dispatch "hl.dsp.send_shortcut({mods=\"$mods\",key=\"V\"})" >/dev/null
fi
