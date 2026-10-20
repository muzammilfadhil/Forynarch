#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-widget-test.XXXXXXXX")"
original_motion="$(hyprctl -j getoption animations:enabled | jq -r '.int==1')"
trap 'hyprctl eval "hl.config({animations={enabled=$original_motion}})" >/dev/null;rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
bash "$root/scripts/build-glass-shader.sh" "$temporary/shaders" >/dev/null
mkdir -p "$temporary/state/forynarch"
python - "$temporary/shell.qml" "$root/tests/qml/WidgetFlow.qml" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]);path.write_text(path.read_text().replace('ShellRoot {','ShellRoot {\n'+Path(sys.argv[2]).read_text(),1))
PY
XDG_STATE_HOME="$temporary/state" timeout 18 qs -p "$temporary"
python - "$temporary/state/forynarch/appearance.json" <<'PY'
import json,sys
from pathlib import Path
state=json.loads(Path(sys.argv[1]).read_text())
assert state['widgetExtras']['battery'] is True
assert state['widgetExtras']['focus'] is False
assert state['widgetPositions']['Virtual-1']['battery']['x']>0
print('PASS: saved widget state persisted to disk')
PY
