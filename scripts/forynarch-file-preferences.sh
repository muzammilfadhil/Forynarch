#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
keys=(misc-single-click misc-folders-first misc-show-hidden misc-confirm-close-multiple-tabs misc-thumbnail-mode last-view misc-use-csd)
properties=(misc-single-click misc-folders-first last-show-hidden misc-confirm-close-multiple-tabs misc-thumbnail-mode last-view misc-use-csd)
defaults=(false true false true THUNAR_THUMBNAIL_MODE_ONLY_LOCAL ThunarIconView true)
case "${1:-status}" in
    status)
        [[ $# -le 1 ]] || exit 2
        result='{}'
        for index in "${!keys[@]}"; do
            value="$(xfconf-query -c thunar -p "/${properties[index]}" 2>/dev/null || printf '%s' "${defaults[index]}")"
            result="$(jq -c --arg key "${keys[index]}" --arg value "$value" '.+{($key):$value}' <<< "$result")"
        done
        printf '%s\n' "$result" ;;
    set)
        [[ $# == 3 ]] || exit 2
        index=-1
        for i in "${!keys[@]}"; do [[ "${keys[i]}" != "$2" ]] || index="$i"; done
        (( index >= 0 )) || exit 2
        case "$2:$3" in
            misc-single-click:true|misc-single-click:false|misc-folders-first:true|misc-folders-first:false|misc-show-hidden:true|misc-show-hidden:false|misc-confirm-close-multiple-tabs:true|misc-confirm-close-multiple-tabs:false|misc-use-csd:true|misc-use-csd:false) type=bool ;;
            misc-thumbnail-mode:THUNAR_THUMBNAIL_MODE_NEVER|misc-thumbnail-mode:THUNAR_THUMBNAIL_MODE_ONLY_LOCAL|misc-thumbnail-mode:THUNAR_THUMBNAIL_MODE_ALWAYS|last-view:ThunarIconView|last-view:ThunarDetailsView|last-view:ThunarCompactView) type=string ;;
            *) echo 'Unsupported file preference.' >&2; exit 2 ;;
        esac
        xfconf-query -c thunar -p "/${properties[index]}" --create -t "$type" -s "$3" ;;
    advanced) [[ $# == 1 ]] || exit 2;exec thunar --preferences ;;
    *) echo 'Usage: forynarch-file-preferences [status|set KEY VALUE|advanced]' >&2;exit 2 ;;
esac
