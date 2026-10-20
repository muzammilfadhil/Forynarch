#!/usr/bin/env bash
# Real standalone QML UI, synthetic account data, no installer executor.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-installer-test.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch-installer/." "$temporary/"
mkdir "$temporary/bin"
installer_info="$(command -v forynarch-installer-info)"
printf '#!/usr/bin/env bash\n"%s" | jq '\'' .executorAvailable=false '\''\n' "$installer_info" > "$temporary/bin/forynarch-installer-info"
chmod 755 "$temporary/bin/forynarch-installer-info"
export PATH="$temporary/bin:$PATH"
bash "$root/scripts/build-installer-shader.sh" "$temporary/shaders"
# Tests run from Live, where Python is an existing test/installer dependency.
python - "$temporary/shell.qml" "$root/tests/qml/InstallerFlow.qml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
source = source.replace('ShellRoot {', 'ShellRoot {\n' + Path(sys.argv[2]).read_text(), 1)
path.write_text(source)
PY
timeout 25 qs -p "$temporary"
