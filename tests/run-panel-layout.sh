#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-panel-test.XXXXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT
cp "$root/config/quickshell/forynarch/ControlCenterLayout.js" "$root/config/quickshell/forynarch/PanelMetrics.js" "$temporary/"
cp "$root/tests/qml/PanelLayout.qml" "$temporary/shell.qml"
timeout 20 qs -p "$temporary"
