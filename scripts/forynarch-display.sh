#!/usr/bin/env bash
# Display previews roll back independently of the Settings window.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 1
transaction="$XDG_RUNTIME_DIR/forynarch-display-preview"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
case "${1:-}" in
  preview)
    [[ $# == 6 && "$2" =~ ^[A-Za-z0-9_.:-]+$ && "$3" =~ ^[0-9]+x[0-9]+@[0-9]+([.][0-9]+)?$ && "$4" =~ ^(1|1.25|1.5|1.75|2)$ && "$5" =~ ^(auto|-?[0-9]+x-?[0-9]+)$ && "$6" =~ ^[0-3]$ ]] || exit 2
    if [[ "$5" != auto ]]; then
      jq -en --arg position "$5" '$position | split("x") | map(tonumber) | all(.[]; .>=-16000 and .<=16000)' >/dev/null || exit 2
    fi
    mkdir -p -- "$transaction"
    exec 9>"$transaction/lock"; flock -x 9
    [[ ! -f "$transaction/pending" ]] || { echo 'Confirm or revert the existing preview first.' >&2; exit 1; }
    monitor="$(hyprctl -j monitors all | jq -ce --arg name "$2" 'first(.[]|select(.name==$name and (.disabled//false|not)))')"
    jq -e --arg mode "$3" 'any(.availableModes[]; rtrimstr("Hz")==$mode)' <<< "$monitor" >/dev/null || { echo 'Choose a reported display mode.' >&2; exit 1; }
    width="${3%%x*}"; height="${3#*x}"; height="${height%%@*}"
    jq -en --argjson width "$width" --argjson height "$height" --argjson scale "$4" '($width/$scale)==($width/$scale|floor) and ($height/$scale)==($height/$scale|floor)' >/dev/null || { echo 'This scale does not produce whole logical pixels.' >&2; exit 1; }
    old_mode="$(jq -r '(.width|tostring)+"x"+(.height|tostring)+"@"+(.refreshRate|tostring)' <<< "$monitor")"
    old_position="$(jq -r '(.x|tostring)+"x"+(.y|tostring)' <<< "$monitor")"
    old_scale="$(jq -r .scale <<< "$monitor")"; old_transform="$(jq -r '.transform//0' <<< "$monitor")"
    token="$(mktemp "$transaction/token.XXXXXXXX")"; token="${token##*/}"
    printf 'hl.monitor({output="%s",mode="%s",position="%s",scale=%s,transform=%s})\n' "$2" "$old_mode" "$old_position" "$old_scale" "$old_transform" > "$transaction/rollback.lua"
    printf 'hl.monitor({output="%s",mode="%s",position="%s",scale=%s,transform=%s})\n' "$2" "$3" "$5" "$4" "$6" > "$transaction/proposed.lua"
    printf '%s\n' "$token" > "$transaction/pending"
    printf '%s\n' "$(( $(date +%s%3N)+15000 ))" > "$transaction/deadline"
    # Release the transaction lock before the guard waits.
    ( exec 9>&-; sleep 15; bash "$0" revert-token "$token" ) >/dev/null 2>&1 &
    hyprctl eval "$(cat "$transaction/proposed.lua")"
    echo 'Preview active for 15 seconds. Keep changes or automatic rollback.'
    ;;
  keep|revert|revert-token)
    [[ -d "$transaction" ]] || exit 0
    exec 9>"$transaction/lock"; flock -x 9
    [[ -f "$transaction/pending" ]] || exit 0
    if [[ "$1" == revert-token ]]; then [[ $# == 2 && "$(cat "$transaction/pending")" == "$2" ]] || exit 0; fi
    if [[ "$1" == keep ]]; then
      mkdir -p -- "$config_home/hypr"
      # Preserve settings for other connected displays rather than replacing all.
      proposed="$(cat "$transaction/proposed.lua")"
      output="$(printf '%s' "$proposed" | sed -n 's/.*output="\([^"]*\)".*/\1/p')"
      pending="$(mktemp "$config_home/hypr/.monitors.XXXXXXXX")"
      if [[ -f "$config_home/hypr/monitors.lua" ]]; then
        awk -v needle="output=\"$output\"" 'index($0,needle)==0 {print}' "$config_home/hypr/monitors.lua" > "$pending"
      fi
      printf '%s\n' "$proposed" >> "$pending"; mv -- "$pending" "$config_home/hypr/monitors.lua"
    else hyprctl eval "$(cat "$transaction/rollback.lua")"; fi
    rm -f -- "$transaction/pending"
    ;;
  status)
    active=false; [[ ! -f "$transaction/pending" ]] || active=true
    deadline=0; [[ ! -f "$transaction/deadline" ]] || read -r deadline < "$transaction/deadline"
    [[ "$deadline" =~ ^[0-9]+$ ]] || deadline=0
    printf '{"preview":%s,"deadline":%s}\n' "$active" "$deadline" ;;
  *) exit 2 ;;
esac
