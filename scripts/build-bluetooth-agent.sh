#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${1:?Usage: build-bluetooth-agent.sh OUTPUT_DIRECTORY}"
for command in qmake6 make g++; do
    command -v "$command" >/dev/null || { printf 'Linux builder tool required: %s\n' "$command" >&2; exit 1; }
done
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
cd "$destination"
qmake6 "$ROOT/native/bluetooth-pair-agent/agent.pro"
make -j2
test -x "$destination/forynarch-bluetooth-pair"
