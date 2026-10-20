#!/usr/bin/env bash
set -euo pipefail
fail() { printf '{"error":"%s","items":[]}\n' "$1"; exit 0; }
[[ $# == 1 && ${#1} -le 200 ]] || fail 'Enter a shorter search.'
config="${XDG_CONFIG_HOME:-$HOME/.config}/forynarch/giphy.json"
[[ -f "$config" ]] || fail 'Add a GIPHY API key to enable GIF search.'
key="$(jq -er '.apiKey | select(type=="string" and test("^[A-Za-z0-9]{1,128}$"))' "$config" 2>/dev/null)" || fail 'Add a GIPHY API key to enable GIF search.'
endpoint=trending; query=''
if [[ -n "$1" ]]; then endpoint=search; query="&q=$(jq -rn --arg value "$1" '$value|@uri')"; fi
# Configuration on stdin keeps the API key out of the process command line.
response="$(printf 'url = "https://api.giphy.com/v1/gifs/%s?api_key=%s&limit=12&rating=g%s"\n' "$endpoint" "$key" "$query" |
    curl --config - --proto '=https' --silent --fail --max-time 15 --max-filesize 1048576 2>/dev/null)" || fail 'GIPHY could not be reached. Try again.'
jq -ce '{error:"",items:[.data[] | {id:.id,title:.title,url:.url,preview:.images.fixed_width_small_still.url,motion:.images.fixed_width_small.url} ]}' <<< "$response" 2>/dev/null || fail 'GIPHY returned an unreadable response.'
