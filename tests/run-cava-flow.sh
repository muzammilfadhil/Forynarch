#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" && -x "${FORYNARCH_TEST_MPRIS_BINARY:-}" ]] || exit 2
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "$XDG_RUNTIME_DIR/forynarch-cava-test.XXXXXXXX")"
original_motion="$(hyprctl -j getoption animations:enabled | jq -r '.int==1')"
old_sink="$(pactl get-default-sink 2>/dev/null || true)"
module='';player_pid='';audio_pid=''
cleanup(){
    [[ -z "$player_pid" ]] || kill "$player_pid" 2>/dev/null || true
    [[ -z "$audio_pid" ]] || kill "$audio_pid" 2>/dev/null || true
    [[ -z "$old_sink" ]] || pactl set-default-sink "$old_sink" 2>/dev/null || true
    [[ -z "$module" ]] || pactl unload-module "$module" 2>/dev/null || true
    hyprctl eval "hl.config({animations={enabled=$original_motion}})" >/dev/null
    rm -r -- "$temporary"
}
trap cleanup EXIT
cp -a "$root/config/quickshell/forynarch/." "$temporary/"
bash "$root/scripts/build-glass-shader.sh" "$temporary/shaders" >/dev/null
mkdir -p "$temporary/state/forynarch"
python - "$temporary/shell.qml" "$root/tests/qml/CavaFlow.qml" "$temporary/tone.wav" <<'PY'
import math,struct,sys,wave
from pathlib import Path
path=Path(sys.argv[1]);path.write_text(path.read_text().replace('ShellRoot {','ShellRoot {\n'+Path(sys.argv[2]).read_text(),1))
with wave.open(sys.argv[3],'wb') as output:
    output.setnchannels(1);output.setsampwidth(2);output.setframerate(22050)
    output.writeframes(b''.join(struct.pack('<h',int(2000*math.sin(2*math.pi*440*i/22050))) for i in range(22050*12)))
PY
module="$(pactl load-module module-null-sink sink_name=forynarch_qa)"
pactl set-default-sink forynarch_qa
"$FORYNARCH_TEST_MPRIS_BINARY" & player_pid=$!
pw-play --target forynarch_qa "$temporary/tone.wav" & audio_pid=$!
XDG_STATE_HOME="$temporary/state" timeout 18 qs -p "$temporary"
