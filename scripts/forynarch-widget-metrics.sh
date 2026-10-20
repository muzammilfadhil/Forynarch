#!/usr/bin/env bash
set -euo pipefail
total=0;available=0
while read -r key value _; do
    case "$key" in MemTotal:) total=$((value*1024));; MemAvailable:) available=$((value*1024));; esac
done < /proc/meminfo
capacity=-1;charging=false
for battery in /sys/class/power_supply/*; do
    [[ -r "$battery/type" && "$(<"$battery/type")" == Battery && -r "$battery/capacity" ]] || continue
    read -r capacity < "$battery/capacity"
    if [[ -r "$battery/status" && "$(<"$battery/status")" == Charging ]]; then charging=true; fi
    break
done
jq -cn --argjson total "$total" --argjson available "$available" --argjson capacity "$capacity" --argjson charging "$charging" \
    '{total:$total,used:($total-$available),capacity:$capacity,charging:$charging}'
