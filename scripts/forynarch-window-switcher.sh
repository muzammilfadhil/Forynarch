#!/usr/bin/env bash
# Freeze the workspace's MRU order until either Alt key is released.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 1
state="$XDG_RUNTIME_DIR/forynarch-window-cycle.json"
exec 9>"$XDG_RUNTIME_DIR/forynarch-window-cycle.lock"; flock -x 9
case "${1:-}" in reset) rm -f -- "$state"; exit 0 ;; next) delta=1 ;; previous) delta=-1 ;; *) exit 2 ;; esac
clients="$(hyprctl -j clients)"
workspace="$(hyprctl -j activeworkspace | jq -er '.id | select(type=="number" and .>0)')"
minimized='{}'
minimized_file="$XDG_RUNTIME_DIR/forynarch-windows/minimized.json"
if [[ -f "$minimized_file" ]];then minimized="$(jq -ce 'select(type=="object")' "$minimized_file")";fi
eligible="$(jq --argjson workspace "$workspace" --argjson minimized "$minimized" '
 [.[] | select(.mapped and
   ((.workspace.id==$workspace and (.hidden|not)) or
    (.workspace.name=="special:forynarch-minimized" and
     $minimized[.address].workspace==$workspace and $minimized[.address].pid==.pid)))]
' <<< "$clients")"
cycle='null'
if [[ -f "$state" ]];then cycle="$(jq -c --argjson workspace "$workspace" 'if .workspace==$workspace then . else null end' "$state")";fi
if [[ "$cycle" == null ]];then
 cycle="$(jq --argjson workspace "$workspace" '{workspace:$workspace,windows:(sort_by(if .focusHistoryID>=0 then .focusHistoryID else 2147483647 end)|map(.address)),index:0}' <<< "$eligible")"
fi
cycle="$(jq --argjson clients "$eligible" --argjson delta "$delta" '
 .windows |= [.[] as $address | $address | select(any($clients[]; .address==$address))] |
 if (.windows|length)==0 then .index=0 else .index=((.index+$delta+(.windows|length)) % (.windows|length)) end' <<< "$cycle")"
address="$(jq -r '.windows[.index] // ""' <<< "$cycle")"
[[ "$address" =~ ^0x[0-9a-fA-F]+$ ]] || exit 0
pending="$(mktemp "$XDG_RUNTIME_DIR/forynarch-window-cycle.XXXXXXXX")"
printf '%s\n' "$cycle" > "$pending";mv -- "$pending" "$state"
if jq -e --arg address "$address" 'any(.[];.address==$address and .workspace.name=="special:forynarch-minimized")' <<< "$eligible" >/dev/null;then
 exec forynarch-window-control activate "$address"
fi
hyprctl dispatch "hl.dsp.focus({window=\"address:$address\"})" >/dev/null
if jq -e --arg address "$address" 'any(.[];.address==$address and .floating)' <<< "$eligible" >/dev/null;then
 hyprctl dispatch "hl.dsp.window.alter_zorder({mode=\"top\",window=\"address:$address\"})" >/dev/null
fi
