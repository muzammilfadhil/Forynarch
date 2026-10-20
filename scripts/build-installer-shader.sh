#!/usr/bin/env bash
# Build-time Qt tool only; generated shader stays out of the installed core.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${1:?Usage: build-installer-shader.sh OUTPUT_DIRECTORY}"
qsb=/usr/lib/qt6/bin/qsb
[[ -x "$qsb" ]] || { echo 'Qt shader compiler is required on the Linux builder (qt6-shadertools).' >&2; exit 1; }
mkdir -p "$destination"
"$qsb" --glsl '100 es,120,150' --hlsl 50 --msl 12 -o "$destination/welcome.frag.qsb" "$ROOT/config/quickshell/forynarch-installer/shaders/welcome.frag"
"$qsb" --version > "$destination/compiler-version.txt"
"$qsb" -d "$destination/welcome.frag.qsb" > "$destination/shader-info.txt"
