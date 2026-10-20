#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
[[ "$(id -u)" == 0 && $# == 1 && "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 2
catalog=/usr/share/forynarch/optional-catalog.json
[[ -f "$catalog" && ! -L "$catalog" && "$(stat -c %u "$catalog")" == 0 ]] || exit 1
selection="$(jq -ce --arg id "$1" '.groups[]|select(.id==$id and .category=="daily")' "$catalog")" || { echo 'Unknown application.' >&2;exit 2; }
mapfile -t packages < <(jq -r '.packages[]' <<< "$selection")
(( ${#packages[@]} > 0 )) || exit 2
for package in "${packages[@]}"; do [[ "$package" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || exit 2;done
if [[ -d /run/archiso && "$(findmnt -nro FSTYPE /run/archiso/cowspace)" == tmpfs ]];then
    # This raises a quota only; tmpfs consumes memory as files are written.
    total_kib="$(awk '/MemTotal:/{print $2}' /proc/meminfo)"
    quota=$((total_kib*1024/3));((quota<=2147483648)) || quota=2147483648
    current="$(findmnt -bnro SIZE /run/archiso/cowspace)"
    if ((quota>current));then mount -o "remount,size=$quota" /run/archiso/cowspace;fi
fi
# A package install also synchronizes the system; never perform a partial upgrade.
exec systemd-run --unit=forynarch-app-install --collect --wait --property=Type=exec --property=RuntimeDirectory=forynarch-app-cache -- /usr/bin/pacman -Syu --needed --noconfirm --cachedir /run/forynarch-app-cache -- "${packages[@]}"
