#!/usr/bin/env bash
set -euo pipefail
[[ -d /run/archiso && -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-focus-test.XXXXXXXX")"
probe_pid=''
trap '[[ -z "$probe_pid" ]] || kill "$probe_pid" 2>/dev/null || true;rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
bash "$root/scripts/build-glass-shader.sh" "$temporary/shaders" >/dev/null
mkdir -p "$temporary/state/forynarch"
python - "$temporary/shell.qml" "$root/tests/qml/PopupFocusFlow.qml" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]);path.write_text(path.read_text().replace('ShellRoot {','ShellRoot {\n'+Path(sys.argv[2]).read_text(),1))
PY
export FORYNARCH_FOCUS_PROBE_FILE="$temporary/keys"
: > "$FORYNARCH_FOCUS_PROBE_FILE"
foot --app-id=forynarch-focus-probe --title='Keyboard focus QA' bash "$root/tests/fixtures/popup-focus-probe.sh" >/dev/null 2>&1 & probe_pid=$!
sleep 1
XDG_STATE_HOME="$temporary/state" timeout 18 qs -p "$temporary"
