#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-glass-qa.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/ControlGlassFallback.qml" "$temporary/shell.qml"
compiled="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/forynarch/shaders/liquid.frag.qsb"
if [[ -s "$compiled" ]];then install -Dm644 "$compiled" "$temporary/shaders/liquid.frag.qsb";fi
timeout 15 qs -p "$temporary"
