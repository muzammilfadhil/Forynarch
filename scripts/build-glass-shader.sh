#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo 'Compile on the Arch builder.' >&2; exit 1; }
destination="${1:-$ROOT/out/glass-shaders}"
qsb=/usr/lib/qt6/bin/qsb
[[ -x "$qsb" ]] || { echo 'Builder prerequisite: reviewed qt6-shadertools package.' >&2; exit 1; }
mkdir -p "$destination"
: > "$destination/shader-info.txt"
for shader in glass motion liquid; do
  "$qsb" --glsl '100 es,120,150' --hlsl 50 --msl 12 \
    -o "$destination/$shader.frag.qsb" "$ROOT/config/quickshell/forynarch/shaders/$shader.frag"
  "$qsb" -d "$destination/$shader.frag.qsb" >> "$destination/shader-info.txt"
done
"$qsb" --version > "$destination/compiler-version.txt"
printf 'Shader compiled: %s\n' "$destination/glass.frag.qsb"
