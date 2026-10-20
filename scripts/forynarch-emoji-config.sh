#!/usr/bin/env bash
set -euo pipefail
umask 077
base="${XDG_CONFIG_HOME:-$HOME/.config}/forynarch"
mkdir -p -- "$base"
payload="$(head -c 2048)"
jq -e 'type=="object" and (keys==["apiKey"]) and (.apiKey|type=="string" and test("^[A-Za-z0-9]{0,128}$"))' <<< "$payload" >/dev/null || exit 2
temp="$(mktemp "$base/.giphy.XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
printf '%s\n' "$payload" > "$temp"
mv -f -- "$temp" "$base/giphy.json"
