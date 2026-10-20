#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-login-video.XXXXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT
theme="$ROOT/config/sddm/themes/forynarch-kath"
cp "$ROOT/tests/qml/LoginVideo.qml" "$temporary/shell.qml"
cp "$theme/Components/VideoBackground.qml" "$temporary/VideoBackground.qml"
cp "$theme/Backgrounds/hyprland_kath.mp4" "$temporary/kath.mp4"
timeout 40 qs -p "$temporary"
