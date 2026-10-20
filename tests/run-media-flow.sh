#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${XDG_RUNTIME_DIR:?}/forynarch-media-qa.XXXXXXXX")"
trap 'rm -r -- "$temporary"' EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
cp "$root/tests/qml/MediaFlow.qml" "$temporary/shell.qml"
mkdir "$temporary/bin"
cat > "$temporary/bin/forynarch-media" <<'HELPER'
#!/usr/bin/env bash
printf 'lookup\n' >> "${FORYNARCH_MEDIA_QA_COUNT:?}"
printf '{"state":"ok","lines":[{"t":0,"text":"Synthetic lyrics"}],"synced":true}\n'
HELPER
chmod 755 "$temporary/bin/forynarch-media"
FORYNARCH_MEDIA_QA_COUNT="$temporary/lookups" PATH="$temporary/bin:$PATH" timeout 15 qs -p "$temporary"
[[ $(wc -l < "$temporary/lookups") == 2 ]]
printf 'PASS exactly two requested lookups; no helper while lyrics disabled, embedded, or widget hidden\n'
