#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-vm-ui.XXXXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/OsVmFlow.qml" "$temporary/shell.qml"
mkdir "$temporary/bin"
install -m755 "$root/tests/fixtures/fake-os-vm.py" "$temporary/bin/forynarch-vm"
export PATH="$temporary/bin:$PATH" FORYNARCH_VM_TEST_STATE="$temporary/state.json"
timeout 75 qs -p "$temporary"
