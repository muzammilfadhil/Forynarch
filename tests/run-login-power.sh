#!/usr/bin/env bash
# Native power UI with inert capabilities and action counters. No real power calls.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-login-power.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
mkdir "$temporary/Components"
cp "$root/config/sddm/themes/forynarch-kath/Components/ForynarchPowerButtons.qml" "$temporary/Components/"
cp "$root/config/sddm/themes/forynarch-kath/Components/ForynarchButton.qml" "$temporary/Components/"
cp "$root/config/sddm/themes/forynarch-kath/Components/NeonFrame.qml" "$temporary/Components/"
cp -a "$root/config/sddm/themes/forynarch-kath/Assets" "$temporary/"
cp "$root/tests/qml/LoginPower.qml" "$temporary/shell.qml"
timeout 20 qs -p "$temporary"
