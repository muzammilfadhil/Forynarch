#!/usr/bin/env bash
set -euo pipefail
[[ -d /run/archiso && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 2
qs -c forynarch ipc call appearance status >/dev/null
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
timeout 15 bash "$root/tests/fixtures/window-mode-flow.sh"
