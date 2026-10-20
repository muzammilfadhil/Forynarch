#!/usr/bin/env bash
# Real QML/Process regression; existing Arch desktop required, no setting writes.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-feedback.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/SettingsFeedback.qml" "$temporary/shell.qml"
timeout 20 qs -p "$temporary"
