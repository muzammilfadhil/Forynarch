#!/usr/bin/env bash
# Storage discovery and non-executable proposals only. No elevation or disk writes.
set -euo pipefail
export LC_ALL=C
shared=/usr/share/forynarch
[[ -f "$shared/storage-inventory.jq" ]] || shared="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
catalog=/usr/share/forynarch/optional-catalog.json
[[ -f "$catalog" ]] || catalog="$shared/../packages/optional-catalog.yaml"
inventory() {
  local live=false uefi=false model revision local_available=false local_filename="" devices
  [[ ! -d /run/archiso ]] || live=true
  [[ ! -d /sys/firmware/efi ]] || uefi=true
  local columns=NAME,PATH,TYPE,SIZE,START,LOG-SEC,MODEL,SERIAL,WWN,TRAN,PTTYPE,PTUUID,PARTTYPE,PARTUUID,PARTLABEL,FSTYPE,LABEL,UUID,MOUNTPOINTS,RO
  local probe=(lsblk --json --bytes --tree --output "$columns")
  [[ "$live" != true ]] || probe+=(--properties-by "blkid,udev")
  # Live has a passwordless policy; read the same device metadata as execution.
  if [[ "$live" == true && $EUID != 0 ]] && devices="$(sudo -n -- "${probe[@]}" 2>/dev/null)"; then
    :
  else
    devices="$("${probe[@]}")"
  fi
  model="$(jq --argjson live "$live" --argjson uefi "$uefi" -f "$shared/storage-inventory.jq" <<< "$devices")"
  revision="$(printf '%s' "$model" | sha256sum | cut -d' ' -f1)"
  if [[ -f "$shared/local-applications.json" ]]; then
    local_filename="$(jq -er '.packages.mudilmusic.filename // empty' "$shared/local-applications.json" 2>/dev/null || true)"
    if [[ "$local_filename" =~ ^mudilmusic-[A-Za-z0-9._+-]+-x86_64\.pkg\.tar\.zst$ && -f "$shared/optional/$local_filename" ]]; then local_available=true;fi
  fi
  jq --arg revision "$revision" --argjson local_available "$local_available" --slurpfile catalog "$catalog" \
    '.+{revision:$revision,software:($catalog[0].groups|map(if .id=="mudilmusic" then .+{available:$local_available} else . end))}' <<< "$model"
}
case "${1:-list}" in
  list) [[ $# -le 1 ]] || exit 2; inventory ;;
  review)
    [[ $# == 2 ]] || exit 2
    # Process substitution supplies only JSON; nothing in the request is executed.
    current="$(inventory)"
    jq -n --slurpfile inventory <(printf '%s' "$current") --slurpfile catalog "$catalog" --argjson request "$2" -f "$shared/storage-plan.jq" ;;
  *) echo 'Usage: forynarch-storage [list|review JSON]' >&2; exit 2 ;;
esac
