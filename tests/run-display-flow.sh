#!/usr/bin/env bash
set -euo pipefail
[[ -n "${FORYNARCH_QA_PRODUCT_UUID:-}" ]] || { echo "Set the UUID of the approved disposable Live VM." >&2; exit 2; }
[[ -d /run/archiso && $(sudo -n cat /sys/class/dmi/id/product_uuid) == "$FORYNARCH_QA_PRODUCT_UUID" && $(id -u) == 1000 ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-display-qa.XXXXXXXX")"
monitors="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors.lua"
forynarch-display status | jq -e '.preview|not' >/dev/null
qs -c forynarch ipc call appearance closePopups
if [[ -f "$monitors" ]];then cp "$monitors" "$temporary/monitors.before";fi
cleanup(){
    forynarch-display revert || true
    if [[ -f "$temporary/monitors.before" ]];then cp "$temporary/monitors.before" "$monitors";else rm -f -- "$monitors";fi
    hyprctl reload >/dev/null
    rm -r -- "$temporary"
}
trap cleanup EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/DisplayFlow.qml" "$temporary/shell.qml"
timeout 40 qs -p "$temporary"
