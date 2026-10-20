#!/usr/bin/env bash
set -euo pipefail
for _ in 1 2 3 4;do
    IFS= read -r -s -n1 key
    printf '%s' "$key" >> "$FORYNARCH_FOCUS_PROBE_FILE"
done
sleep 2
