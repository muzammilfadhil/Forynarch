#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-emoji-test.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/EmojiFlow.qml" "$temporary/shell.qml"
mkdir -p "$temporary/state/forynarch"
PATH="$root/scripts:$PATH" XDG_STATE_HOME="$temporary/state" timeout 20 qs -p "$temporary"
