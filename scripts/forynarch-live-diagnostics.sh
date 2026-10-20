#!/usr/bin/env bash
# Read-only report: no cache clearing, unmounting, network identifiers or secrets.
set -euo pipefail
[[ $# == 0 && -r /proc/meminfo ]] || exit 2
live=false; [[ ! -d /run/archiso ]] || live=true
copied=false; mountpoint -q /run/archiso/copytoram && copied=true
requested="$(awk '{for(i=1;i<=NF;i++) if($i ~ /^copytoram=(auto|y|n)$/) value=$i} END {sub(/^copytoram=/,"",value); print value ? value : "unspecified"}' /proc/cmdline)"
copy_bytes=0
if [[ "$copied" == true ]]; then
    for image in /run/archiso/copytoram/airootfs.sfs /run/archiso/copytoram/airootfs.erofs; do
        [[ ! -f "$image" ]] || copy_bytes="$(stat -Lc '%s' "$image")"
    done
fi
cow_bytes=0
if mountpoint -q /run/archiso/cowspace; then
    cow_bytes="$(df -B1 --output=used /run/archiso/cowspace | awk 'NR==2 {print $1}')"
fi
memory="$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^SwapTotal:/ {s=$2} /^SwapFree:/ {f=$2} /^Shmem:/ {m=$2} /^Cached:/ {c=$2} /^SReclaimable:/ {r=$2} END {printf "{\"totalBytes\":%.0f,\"availableBytes\":%.0f,\"usedBytes\":%.0f,\"swapUsedBytes\":%.0f,\"sharedBytes\":%.0f,\"pageCacheBytes\":%.0f,\"reclaimableSlabBytes\":%.0f}",t*1024,a*1024,(t-a)*1024,(s-f)*1024,m*1024,c*1024,r*1024}' /proc/meminfo)"
jq -n --argjson live "$live" --arg requested "$requested" --argjson copied "$copied" --argjson copiedBytes "$copy_bytes" --argjson cowBytes "$cow_bytes" --argjson memory "$memory" \
    '{session:(if $live then "live" else "installed" end),memory:$memory,liveImage:{copyToRamRequested:$requested,copyToRamActive:$copied,copiedImageBytes:$copiedBytes,writableOverlayBytes:$cowBytes},notes:["usedBytes is MemTotal minus MemAvailable; swap is separate.","Cache, shared memory, copied image and overlay are overlapping accounting categories; do not add them together.","A Live report does not establish installed-core idle memory acceptance.","External bootloader Memdisk allocation is not identified by this report."]}'
