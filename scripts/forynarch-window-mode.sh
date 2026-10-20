#!/usr/bin/env bash
set -euo pipefail
base="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$base/forynarch" "$base/hypr"
state="$base/forynarch/window-modes.json"
[[ -f "$state" ]] || printf '{}\n' > "$state"
exec 8>"$base/forynarch/window-modes.lock";flock -x 8
jq -e 'type=="object" and length<=256 and all(to_entries[];(.key|test("^[0-9]{1,6}$")) and (.value=="dwindle" or .value=="hybrid" or .value=="master" or .value=="scrolling" or .value=="floating"))' "$state" >/dev/null
sizes="$base/forynarch/window-sizes.json"
[[ -f "$sizes" ]] || printf '{}\n' > "$sizes"
jq -e 'type=="object" and length<=256 and all(to_entries[];(.key|test("^[0-9]{1,6}$")) and (.value=="compact" or .value=="comfortable" or .value=="spacious"))' "$sizes" >/dev/null
workspace="$(hyprctl -j activeworkspace | jq -er '.id|select(.>=1 and .<=999999)')"
current="$(jq -r --arg id "$workspace" '.[$id]//"dwindle"' "$state")"
action="${1:-status}"
size="$(jq -r --arg id "$workspace" '.[$id]//"comfortable"' "$sizes")"
if [[ "$action" == status ]];then jq -cn --arg mode "$current" --arg size "$size" '{mode:$mode,size:$size}';exit 0;fi
if [[ "$action" == fit ]];then
    [[ $# == 1 ]] || exit 2
    client="$(hyprctl -j activewindow)"
    address="$(jq -er '.address|select(test("^0x[a-fA-F0-9]+$"))' <<< "$client")"
    monitor="$(jq -er '.monitor' <<< "$client")"
    case "$size" in compact)ratio=.60;;comfortable)ratio=.72;;spacious)ratio=.86;;esac
    read -r width height < <(hyprctl -j monitors | jq -r --argjson id "$monitor" --argjson ratio "$ratio" '.[]|select(.id==$id)|. as $m|(if (.transform%2)==1 then [.height,.width] else [.width,.height] end) as $pixels|[(($pixels[0]/$m.scale-$m.reserved[0]-$m.reserved[2])*$ratio|floor),(($pixels[1]/$m.scale-$m.reserved[1]-$m.reserved[3])*$ratio|floor)]|@tsv')
    [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || exit 1
    hyprctl dispatch "hl.dsp.window.float({action=\"on\",window=\"address:$address\"})" >/dev/null
    hyprctl dispatch "hl.dsp.window.resize({x=$width,y=$height,window=\"address:$address\"})" >/dev/null
    exec hyprctl dispatch "hl.dsp.window.center({window=\"address:$address\"})"
fi
if [[ "$action" == size ]];then
    [[ $# == 2 && "$2" =~ ^(compact|comfortable|spacious)$ ]] || exit 2
    size="$2"
    temporary="$(mktemp "$base/forynarch/.window-sizes.XXXXXXXX")"
    jq --arg id "$workspace" --arg size "$size" '.[$id]=$size' "$sizes" > "$temporary"
    mv -f -- "$temporary" "$sizes"
    action="$current"
    set -- "$current"
fi
mode="$action"
if [[ "$mode" == cycle ]];then case "$current" in dwindle)mode=hybrid;;hybrid)mode=floating;;floating)mode=scrolling;;*)mode=dwindle;;esac;fi
[[ "$mode" =~ ^(dwindle|hybrid|master|scrolling|floating)$ ]] || exit 2
[[ $# == 1 || ( $# == 2 && "$2" == --apply-open ) ]] || exit 2
temporary="$(mktemp "$base/forynarch/.window-modes.XXXXXXXX")"
trap 'rm -f -- "$temporary"' EXIT
jq --arg id "$workspace" --arg mode "$mode" '.[$id]=$mode' "$state" > "$temporary"
mv -f -- "$temporary" "$state"
module="$(mktemp "$base/hypr/.window-modes.XXXXXXXX")"
utility='^(org[.]xfce[.]Thunar|thunar|Thunar|org[.]pulseaudio[.]pavucontrol|pavucontrol|nm-connection-editor|blueman-manager|org[.]kde[.]partitionmanager)$'
printf 'hl.config({general={resize_on_border=true,extend_border_grab_area=12}})\n' > "$module"
jq -r --slurpfile sizes "$sizes" --arg utility "$utility" 'to_entries[] |
    ($sizes[0][.key]//"comfortable") as $size |
    (if $size=="compact" then "monitor_w*0.60 monitor_h*0.60" elif $size=="spacious" then "monitor_w*0.86 monitor_h*0.86" else "monitor_w*0.72 monitor_h*0.72" end) as $geometry |
    "hl.workspace_rule({workspace=\""+.key+"\",layout=\""+(if .value=="floating" or .value=="hybrid" then "dwindle" else .value end)+"\"})\n" +
"hl.window_rule({name=\"forynarch-float-"+.key+"\",match={workspace=\""+.key+"\"},float=true,center=true,size="+($geometry|tojson)+",enabled="+((.value=="floating")|tostring)+"})\n" +
"hl.window_rule({name=\"forynarch-hybrid-"+.key+"\",match={workspace=\""+.key+"\",initial_class="+($utility|tojson)+"},float=true,center=true,size="+($geometry|tojson)+",enabled="+((.value=="hybrid")|tostring)+"})"' "$state" >> "$module"
mv -f -- "$module" "$base/hypr/workspace-modes.lua"
hyprctl eval "$(cat "$base/hypr/workspace-modes.lua")" >/dev/null
if [[ "${2:-}" == --apply-open ]];then
    while read -r address floating;do
        [[ "$address" =~ ^0x[a-fA-F0-9]+$ ]] || exit 1
        action='off';[[ "$floating" != true ]] || action='on'
        hyprctl dispatch "hl.dsp.window.float({action=\"$action\",window=\"address:$address\"})" >/dev/null
    done < <(hyprctl -j clients | jq -r --argjson id "$workspace" --arg mode "$mode" --arg utility "$utility" '.[]|select(.workspace.id==$id)|. as $client|($mode=="floating" or ($mode=="hybrid" and ((.initialClass//.class)|test($utility)))) as $floating|select($client.floating!=$floating)|[.address,($floating|tostring)]|@tsv')
fi
flock -u 8
exec 8>&-
qs -c forynarch ipc call appearance refreshWindowMode >/dev/null 2>&1 || true
