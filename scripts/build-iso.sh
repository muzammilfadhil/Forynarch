#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/arch-environment.sh
source "$ROOT/scripts/arch-environment.sh"
require_arch_environment
PROFILE="$ROOT/archiso/profile"
require_local_destination "$PROFILE"
require_local_destination "$ROOT/work"
require_local_destination "$ROOT/out"

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "Error: mkarchiso not found. Install archiso on Arch Linux." >&2
  exit 1
fi
if [[ ! -f "$PROFILE/profiledef.sh" ]]; then
  echo "Error: No Archiso profile in $PROFILE" >&2
  echo "Run ./scripts/setup-profile.sh inside an Arch Linux VM first." >&2
  exit 1
fi
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run using sudo from Arch Linux: sudo ./scripts/build-iso.sh" >&2
  exit 1
fi
if [[ -d "$ROOT/work" && -n "$(find "$ROOT/work" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -print -quit)" ]]; then
  echo "Error: work directory is not empty. Review/archive the previous build before a clean build." >&2
  exit 1
fi
mkdir -p "$ROOT/work" "$ROOT/out"
record="$ROOT/out/build-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir "$record"
"$ROOT/scripts/record-build-environment.sh" > "$record/environment.txt"
python "$ROOT/scripts/live_boot_policy.py" "$PROFILE" > "$record/live-boot-policy.txt"
find "$PROFILE" -type f -print0 | sort -z | while IFS= read -r -d '' file; do
  (cd "$PROFILE" && sha256sum "${file#"$PROFILE/"}")
done > "$record/profile.sha256"
mkarchiso -v -w "$ROOT/work" -o "$record" "$PROFILE"
find "$record" -maxdepth 1 -type f -name '*.iso' -print0 | sort -z | while IFS= read -r -d '' file; do
  (cd "$record" && sha256sum "${file#"$record/"}")
done > "$record/iso.sha256"
echo "Build completed. Check $ROOT/out"
