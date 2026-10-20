#!/usr/bin/env bash
set -euo pipefail
shared=/usr/share/forynarch
catalog="$shared/optional-catalog.json"
[[ -r "$catalog" ]] || { echo 'Application catalog is unavailable.' >&2;exit 1; }
case "${1:-list}" in
    list)
        [[ $# -le 1 ]] || exit 2
        live=false;[[ ! -d /run/archiso ]] || live=true
        result="$(jq --argjson live "$live" '{live:$live,apps:([.groups[]|select(.category=="daily")|.+{available:true}]+[{id:"arc",label:"Arc",description:"No supported native Linux release is available.",available:false}])}' "$catalog")"
        while IFS= read -r entry; do
            installed=true
            id="$(jq -r .id <<< "$entry")"
            while IFS= read -r package; do pacman -Q "$package" >/dev/null 2>&1 || installed=false;done < <(jq -r '.packages[]' <<< "$entry")
            while IFS= read -r app; do
                if ! command -v flatpak >/dev/null || ! flatpak --user info "$app" >/dev/null 2>&1; then installed=false;fi
            done < <(jq -r '.flatpaks // [] | .[]' <<< "$entry")
            result="$(jq --arg id "$id" --argjson installed "$installed" '.apps |= map(if .id==$id then .+{installed:$installed} else . end)' <<< "$result")"
        done < <(jq -c '.groups[]|select(.category=="daily")' "$catalog")
        printf '%s\n' "$result" ;;
    install)
        [[ $# == 2 && "$2" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 2
        entry="$(jq -ce --arg id "$2" '.groups[]|select(.id==$id and .category=="daily")' "$catalog")" || { echo 'Unknown application.' >&2;exit 2; }
        printf 'Live trial installs use temporary storage and memory. Large applications may exceed the available space. Changes are discarded after reboot.\n'
        pkexec /usr/local/libexec/forynarch-install-app "$2"
        mapfile -t apps < <(jq -r '.flatpaks // [] | .[]' <<< "$entry")
        if (( ${#apps[@]} )); then
            flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            flatpak --user install --noninteractive --or-update flathub "${apps[@]}"
        fi ;;
    *) echo 'Usage: forynarch-apps [list|install APP_ID]' >&2;exit 2 ;;
esac
