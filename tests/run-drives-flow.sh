#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-drives-qa.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/DrivesFlow.qml" "$temporary/shell.qml"
mkdir "$temporary/bin"
cat > "$temporary/bin/forynarch-drives" <<'HELPER'
#!/usr/bin/env python3
import sys,json
if sys.argv[1]=='unlock':
    assert len(sys.argv)==3 and sys.stdin.read()=='fixture-only-key\n'
    print('Unlocked fixture read-only');sys.exit(0)
assert sys.argv[1]=='list'
print(json.dumps([{'id':'partuuid:fixture','device':'/dev/fake1','name':'Windows (C:)','letter':'C','filesystem':'BitLocker','size':128000000000,'protected':False,'locked':True,'canUnlock':True,'canMount':False,'mounted':False,'encrypted':True,'mountpoint':'','readOnly':False}]))
HELPER
chmod 755 "$temporary/bin/forynarch-drives"
PATH="$temporary/bin:$PATH" timeout 12 qs -p "$temporary"
