#!/usr/bin/env bash
# Read-only Linux guest measurement. No cache clearing, swap changes or installs.
set -euo pipefail
samples="${1:-12}"
interval="${2:-5}"
limit_bytes="${3:-3000000000}"
[[ "$samples" =~ ^[0-9]+$ && "$interval" =~ ^[0-9]+$ && "$limit_bytes" =~ ^[0-9]+$ ]] || exit 2
(( samples >= 1 && samples <= 120 && interval >= 1 && interval <= 30 && limit_bytes >= 1 )) || exit 2
[[ "$(uname -s)" == Linux && -r /proc/meminfo ]] || { echo 'Run inside the Linux guest.' >&2; exit 1; }
peak=0
for ((index=1; index<=samples; index++)); do
  read -r total available swap_total swap_free < <(
    awk '/^MemTotal:/ {t=$2*1024} /^MemAvailable:/ {a=$2*1024}
         /^SwapTotal:/ {s=$2*1024} /^SwapFree:/ {f=$2*1024}
         END {printf "%.0f %.0f %.0f %.0f\n", t,a,s,f}' /proc/meminfo)
  (( total > 0 && available >= 0 && available <= total )) || exit 1
  used=$((total-available))
  swap_used=$((swap_total-swap_free))
  (( used <= peak )) || peak=$used
  printf '{"sample":%d,"used_bytes":%d,"total_bytes":%d,"available_bytes":%d,"swap_used_bytes":%d}\n' \
    "$index" "$used" "$total" "$available" "$swap_used"
  if (( index < samples )); then sleep "$interval"; fi
done
printf 'Peak used: %d bytes; limit: %d bytes. This command cannot establish whether the session was truly idle.\n' \
  "$peak" "$limit_bytes" >&2
(( peak < limit_bytes ))
