#!/usr/bin/env bash
# Non-executable installation review. Account secrets are never accepted.
set -euo pipefail
[[ $# == 1 ]] || { echo 'Usage: forynarch-installer-review JSON' >&2; exit 2; }
request=$1
shared=/usr/share/forynarch
[[ -f "$shared/installer-review.jq" ]] || shared="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
info="$(forynarch-installer-info)"
review="$(forynarch-storage review "$request" | jq --argjson request "$request" --argjson info "$info" -f "$shared/installer-review.jq")"
jq -n --argjson plan "$request" --argjson inventory "$info" --argjson review "$review" '{plan:$plan,inventory:$inventory,review:$review}' |
    python "$shared/install_layout.py" review
