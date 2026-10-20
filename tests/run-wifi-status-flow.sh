#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-wifi-status.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/WifiStatusFlow.qml" "$temporary/shell.qml"
timeout 15 qs -p "$temporary"
