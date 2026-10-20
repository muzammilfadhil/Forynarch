#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && -d "$1/etc" ]] || exit 2
python - "$1" <<'PY'
import json,sys
from pathlib import Path
path=Path(sys.argv[1])/"etc/firefox/policies/policies.json"
data=json.loads(path.read_text()) if path.exists() else {"policies":{}}
data.setdefault("policies",{})["DisplayMenuBar"]="never"
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(data,indent=2)+"\n")
path.chmod(0o644)
PY
