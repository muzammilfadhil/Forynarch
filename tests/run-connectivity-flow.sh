#!/usr/bin/env bash
# Production QML with isolated synthetic services and a scoped fake pairing helper.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-connectivity.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/ConnectivityFlow.qml" "$temporary/shell.qml"
if [[ "${FORYNARCH_CONNECTIVITY_PANEL:-0}" == 1 ]]; then
    sed -i 's/FloatingWindow {/PanelWindow {/;s/title: "Connectivity test fixtures"; //' "$temporary/shell.qml"
fi
mkdir "$temporary/bin"
install -m755 "$root/tests/fixtures/fake-bluetooth-pair.sh" "$temporary/bin/forynarch-bluetooth-pair"
PATH="$temporary/bin:$PATH" timeout 30 qs -p "$temporary"
