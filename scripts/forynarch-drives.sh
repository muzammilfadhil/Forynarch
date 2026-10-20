#!/usr/bin/env bash
# On-demand storage UI/backend. No polling daemon, automount, formatting or repair.
set -euo pipefail
set +x
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/forynarch"
mapping="$config_dir/windows-drives.json"
model=/usr/share/forynarch/storage-model.jq
[[ -f "$model" ]] || model="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/storage-model.jq"
valid_mapping() {
  jq -e '.version == 1 and (.drives | type == "array") and
    all(.drives[]; (.id | type == "string") and (.id | test("^(partuuid|uuid):[a-z0-9-]+$")) and
      (.letter | type == "string") and (.letter | test("^[C-Z]$")) and
      (.label | type == "string") and (.label | length <= 64) and (.label | explode | all(. >= 32 and . != 127))) and
    ([.drives[].id] | unique | length) == (.drives | length) and
    ([.drives[].letter] | unique | length) == (.drives | length)' "$1" >/dev/null
}
inventory() (
  local temporary
  temporary="$(mktemp -d)"
  trap 'rm -r -- "$temporary"' EXIT
  lsblk --json --bytes --output PATH,TYPE,FSTYPE,LABEL,UUID,PARTUUID,PARTTYPE,SIZE,MOUNTPOINTS,RO > "$temporary/devices.json"
  findmnt --json --list --output TARGET,OPTIONS > "$temporary/mounts.json"
  if [[ -f "$mapping" ]]; then
    if ! valid_mapping "$mapping"; then echo 'Invalid drive mapping; no action taken.' >&2; return 1; fi
    cp -- "$mapping" "$temporary/map.json"
  else printf '{"version":1,"drives":[]}\n' > "$temporary/map.json"; fi
  jq -n --slurpfile devices "$temporary/devices.json" --slurpfile mounts "$temporary/mounts.json" \
    --slurpfile mapping "$temporary/map.json" -f "$model"
)
save_mapping() {
  mkdir -p -- "$config_dir"
  local pending
  pending="$(mktemp "$config_dir/.windows-drives.XXXXXXXX")"
  cat > "$pending"
  if ! valid_mapping "$pending"; then rm -- "$pending"; echo 'Invalid or duplicate drive alias.' >&2; return 1; fi
  mv -- "$pending" "$mapping"
}
select_drive() {
  [[ "$1" =~ ^(partuuid|uuid):[a-z0-9-]+$ ]] || { echo 'Use a stable partition/filesystem ID.' >&2; return 2; }
  inventory | jq -ce --arg id "$1" '[.[] | select(.id == $id)] |
    if length == 1 then .[0] else error("Drive missing or identifier ambiguous") end'
}
bookmark_drive() {
  local entry="$1" uri bookmarks
  [[ "$(jq -r '.mounted and (.letter != "")' <<< "$entry")" == true ]] || return 0
  bookmarks="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks"
  uri="$(jq -nr --arg path "$(jq -r '.mountpoint' <<< "$entry")" '$path | split("/") | map(@uri) | join("/") | "file://" + .')"
  if [[ -f "$bookmarks" ]] && awk -v uri="$uri" '$1==uri {found=1} END {exit !found}' "$bookmarks"; then return 0; fi
  mkdir -p -- "$(dirname -- "$bookmarks")"
  printf '%s %s\n' "$uri" "$(jq -r '.name' <<< "$entry")" >> "$bookmarks"
}
case "${1:-ui}" in
  ui)
    if command -v qs >/dev/null && qs -c forynarch ipc call appearance openDrives >/dev/null 2>&1; then exit 0; fi
    exec forynarch-terminal --title='Drives and storage' bash -c 'forynarch-drives list; printf "\nPress Enter to close."; read -r'
    ;;
  list) [[ $# == 1 ]] || exit 2; inventory ;;
  import|merge)
    [[ $# == 2 && -f "$2" ]] || exit 2
    valid_mapping "$2" || { echo 'Invalid Windows drive map.' >&2; exit 1; }
    mkdir -p -- "$config_dir"; exec 9>"$config_dir/drive-map.lock"; flock -x 9
    if [[ "$1" == merge ]];then
      current='{"version":1,"drives":[]}'
      if [[ -f "$mapping" ]];then valid_mapping "$mapping";current="$(cat "$mapping")";fi
      jq --slurpfile incoming "$2" '
        ($incoming[0].drives | map(.id)) as $ids |
        ($incoming[0].drives | map(.letter)) as $letters |
        .drives = ([.drives[] | select(.id as $id | ($ids | index($id)) == null) |
          select(.letter as $letter | ($letters | index($letter)) == null)] + $incoming[0].drives)
      ' <<< "$current" | save_mapping
      while IFS= read -r entry;do bookmark_drive "$entry";done < <(inventory | jq -c '.[] | select(.mounted and .letter!="")')
      echo 'Windows drive letters synchronized. No disk was mounted or changed.'
      exit 0
    elif [[ -f "$mapping" ]]; then
      echo 'A mapping already exists. Review it before replacing; import refused.' >&2; exit 1
    fi
    save_mapping < "$2"
    echo 'Drive labels imported. No disk was mounted or changed.'
    ;;
  alias)
    [[ $# == 3 && "$3" =~ ^[C-Z]$ ]] || exit 2
    drive="$(select_drive "$2")"
    [[ "$(jq -r '.protected' <<< "$drive")" == false ]] || { echo 'Protected partition cannot receive a drive alias.' >&2; exit 1; }
    mkdir -p -- "$config_dir"; exec 9>"$config_dir/drive-map.lock"; flock -x 9
    current='{"version":1,"drives":[]}'
    if [[ -f "$mapping" ]]; then valid_mapping "$mapping"; current="$(cat "$mapping")"; fi
    jq -e --arg id "$2" --arg letter "$3" 'all(.drives[]; .letter != $letter or .id == $id)' <<< "$current" >/dev/null || {
      echo 'That letter belongs to another drive. Choose a different letter.' >&2; exit 1;
    }
    jq --arg id "$2" --arg letter "$3" --arg label "$(jq -r '.label | if . == "" then "Drive" else . end' <<< "$drive")" \
      '.drives = [.drives[] | select(.id != $id)] + [{id:$id,letter:$letter,label:$label}]' <<< "$current" | save_mapping
    bookmark_drive "$(select_drive "$2")"
    echo 'Alias saved. Windows and partition labels were not changed.'
    ;;
  mount-ro|open|unmount|unlock|lock)
    [[ $# == 2 && "$(id -u)" != 0 ]] || { echo 'Run this action as your desktop user.' >&2; exit 2; }
    drive="$(select_drive "$2")"
    [[ "$(jq -r '.protected' <<< "$drive")" == false ]] || { echo 'Protected partition. No action taken.' >&2;exit 1; }
    if [[ "$1" == unlock ]];then
      [[ "$(jq -r '.canUnlock' <<< "$drive")" == true ]] || { echo 'This drive is not locked.' >&2;exit 1; }
    elif [[ "$1" == lock ]];then
      [[ "$(jq -r '.encrypted and (.locked|not) and (.mounted|not)' <<< "$drive")" == true ]] || { echo 'Unmount the unlocked drive before locking it.' >&2;exit 1; }
    else
      [[ "$(jq -r '.canMount' <<< "$drive")" == true ]] || { echo 'Locked or unsupported volume. Unlock it first.' >&2; exit 1; }
    fi
    device="$(jq -r '.device' <<< "$drive")"
    [[ -b "$device" ]] || { echo 'Device is no longer present.' >&2; exit 1; }
    kind="${2%%:*}"; stable="/dev/disk/by-$kind/${2#*:}"
    if [[ "$kind" == uuid ]]; then
      actual_uuid="$(jq -r '.uuid' <<< "$drive")"
      [[ "$actual_uuid" =~ ^[A-Za-z0-9-]+$ ]] || exit 1
      stable="/dev/disk/by-uuid/$actual_uuid"
    fi
    [[ "$(readlink -e -- "$stable")" == "$(readlink -e -- "$(jq -r '.blockDevice // .device' <<< "$drive")")" ]] || {
      echo 'Drive identity changed. Refresh before trying again.' >&2; exit 1;
    }
    if [[ "$1" == unlock ]];then
      credential=''
      if [[ -t 0 ]];then printf 'Password or BitLocker recovery key: ' >&2;fi
      IFS= read -rs credential || { echo 'Unlock cancelled.' >&2;exit 1; }
      [[ -n "$credential" && ${#credential} -le 512 ]] || { echo 'Enter a password or recovery key.' >&2;exit 1; }
      printf '%s' "$credential" | udisksctl unlock --block-device "$stable" --read-only --key-file /dev/stdin
      unset credential
      echo 'Drive unlocked read-only. Choose Mount read-only to browse files.'
      exit 0
    elif [[ "$1" == lock ]];then
      exec udisksctl lock --block-device "$stable"
    fi
    if [[ "$1" == mount-ro ]]; then
      [[ "$(jq -r '.mounted' <<< "$drive")" == false ]] || { echo 'Already mounted. Review its current access mode.' >&2; exit 1; }
      udisksctl mount --block-device "$device" --options ro
      drive="$(select_drive "$2")"
      [[ "$(jq -r '.mounted and .readOnly' <<< "$drive")" == true ]] || { echo 'Read-only mount could not be confirmed.' >&2; exit 1; }
    elif [[ "$1" == unmount ]]; then
      [[ "$(jq -r '.mounted' <<< "$drive")" == true ]] || exit 0
      exec udisksctl unmount --block-device "$device"
    fi
    mountpoint="$(jq -r '.mountpoint' <<< "$drive")"
    [[ -n "$mountpoint" && -d "$mountpoint" ]] || { echo 'Mount the drive first.' >&2; exit 1; }
    bookmark_drive "$drive"
    forynarch-files "$mountpoint" >/dev/null 2>&1 &
    echo 'Opening files in File Manager.'
    ;;
  *) echo 'Usage: forynarch-drives [ui|list|import FILE|merge FILE|alias ID C|mount-ro ID|unlock ID|lock ID|open ID|unmount ID]' >&2; exit 2 ;;
esac
