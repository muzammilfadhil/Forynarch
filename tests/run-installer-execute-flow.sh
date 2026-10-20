#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-execute-test.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch-installer/." "$temporary/"
bash "$root/scripts/build-installer-shader.sh" "$temporary/shaders"
mkdir "$temporary/bin"
install -m755 "$root/tests/fixtures/fake-system-install.py" "$temporary/bin/pkexec"
python - "$temporary/shell.qml" "$root/tests/qml/InstallerExecuteFlow.qml" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1])
path.write_text(path.read_text().replace('ShellRoot {','ShellRoot {\n'+Path(sys.argv[2]).read_text(),1))
PY
PATH="$temporary/bin:$PATH" timeout 20 qs -p "$temporary"
