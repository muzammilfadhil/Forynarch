#!/usr/bin/env bash
set -euo pipefail
pids=()
original="$(forynarch-window-mode status | jq -r .mode)"
original_size="$(forynarch-window-mode status | jq -r .size)"
cleanup(){
    for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;done
    forynarch-window-mode "$original" >/dev/null
    forynarch-window-mode size "$original_size" >/dev/null
}
trap cleanup EXIT
trap 'exit 143' TERM HUP INT
address(){ hyprctl -j clients | jq -er --arg class "$1" 'first(.[]|select(.class==$class))|.address'; }
floating(){ hyprctl -j clients | jq -r --arg address "$1" '.[]|select(.address==$address)|.floating'; }
forynarch-window-mode dwindle
forynarch-window-mode size comfortable
foot --app-id=forynarch-qa-existing --title='Existing-window QA' sh -c 'sleep 45' & pids+=("$!")
sleep 1
first="$(address forynarch-qa-existing)"
[[ $(floating "$first") == false ]]
forynarch-window-mode floating
[[ $(floating "$first") == false ]]
foot --app-id=forynarch-qa-new --title='New-window QA' sh -c 'sleep 45' & pids+=("$!")
sleep 1
second="$(address forynarch-qa-new)"
[[ $(floating "$second") == true ]]
size_before="$(hyprctl -j clients | jq -c --arg address "$second" '.[]|select(.address==$address)|.size')"
forynarch-window-mode size compact
[[ "$(hyprctl -j clients | jq -c --arg address "$second" '.[]|select(.address==$address)|.size')" == "$size_before" ]]
foot --app-id=forynarch-qa-compact --title='Compact floating QA' sh -c 'sleep 45' & pids+=("$!")
sleep 1
compact="$(address forynarch-qa-compact)"
hyprctl -j clients | jq -e --arg a "$compact" --arg b "$second" '[.[]|select(.address==$a)|.size[0]][0] < [.[]|select(.address==$b)|.size[0]][0]' >/dev/null
hyprctl dispatch "hl.dsp.focus({window=\"address:$compact\"})" >/dev/null
forynarch-window-mode size spacious
forynarch-window-mode fit >/dev/null
sleep .4
hyprctl -j clients | jq -e --arg a "$compact" --arg b "$second" '[.[]|select(.address==$a)|.size[0]][0] > [.[]|select(.address==$b)|.size[0]][0]' >/dev/null
hyprctl dispatch "hl.dsp.window.float({action=\"off\",window=\"address:$second\"})" >/dev/null
[[ $(floating "$second") == false && $(forynarch-window-mode status | jq -r .mode) == floating ]]
forynarch-window-mode hybrid
foot --app-id=Thunar --title='Hybrid utility QA' sh -c 'sleep 45' & pids+=("$!")
foot --app-id=forynarch-qa-hybrid-main --title='Hybrid main QA' sh -c 'sleep 45' & pids+=("$!")
sleep 1
[[ $(floating "$(address Thunar)") == true && $(floating "$(address forynarch-qa-hybrid-main)") == false ]]
for mode in master scrolling dwindle;do forynarch-window-mode "$mode";[[ -z $(hyprctl configerrors) ]];done
forynarch-window-mode size comfortable
echo 'PASS: hybrid utility/main defaults, resizable floating geometry, size presets, existing windows and manual overrides; no IPC lock deadlock'
