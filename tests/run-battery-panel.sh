#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-battery-test.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/BatteryPanelFlow.qml" "$temporary/shell.qml"
for style in classic macshell; do
    for width in 800 1024 1280; do
        FORYNARCH_PANEL_TEST_STYLE="$style" FORYNARCH_PANEL_TEST_WIDTH="$width" timeout 20 qs -p "$temporary"
    done
done
