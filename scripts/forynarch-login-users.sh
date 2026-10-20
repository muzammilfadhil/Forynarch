#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
[[ $# == 0 && "$(id -u)" == 0 ]] || exit 2
configuration=/usr/share/sddm/themes/forynarch-kath/Themes/hyprland_kath.conf.user
[[ -d "${configuration%/*}" && ! -L "$configuration" ]] || exit 1
# Only names are published; locked hashes and service users never qualify.
names="$(getent shadow | awk -F: '$2=="" {print $1}' | while IFS= read -r user; do
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || continue
    entry="$(getent passwd "$user")"
    IFS=: read -r _ _ uid _ _ _ shell <<< "$entry"
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid < 65534 )) || continue
    [[ "$shell" != */nologin && "$shell" != */false ]] || continue
    printf '%s\n' "$user"
done | paste -sd, -)"
temporary="$(mktemp "${configuration}.XXXXXXXX")"
trap 'rm -f -- "$temporary"' EXIT
if [[ -f "$configuration" ]]; then sed '/^[[:space:]]*PasswordlessUsers[[:space:]]*=/d' "$configuration" > "$temporary"; fi
printf '\n[General]\nPasswordlessUsers="%s"\n' "$names" >> "$temporary"
chmod 644 "$temporary"
mv -f -- "$temporary" "$configuration"
