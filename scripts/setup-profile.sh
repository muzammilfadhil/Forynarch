#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/arch-environment.sh
source "$ROOT/scripts/arch-environment.sh"
require_arch_environment
SOURCE="/usr/share/archiso/configs/releng"
TARGET="$ROOT/archiso/profile"
require_local_destination "$TARGET"

if [[ ! -f "$SOURCE/profiledef.sh" ]]; then
  echo "Error: Official Archiso releng profile not found at $SOURCE" >&2
  echo "Install archiso inside an Arch Linux VM first." >&2
  exit 1
fi
if [[ -f "$TARGET/profiledef.sh" ]]; then
  echo "Profile already prepared: $TARGET"
  echo "Not overwriting local customizations."
  exit 0
fi
mkdir -p "$TARGET"
# Do not overwrite unrelated contents in the target folder.
if [[ -n "$(find "$TARGET" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -print -quit)" ]]; then
  echo "Error: Target profile is not empty. Review existing files before copying." >&2
  exit 1
fi
cp -a "$SOURCE/." "$TARGET/"
python "$ROOT/scripts/live_boot_policy.py" "$TARGET"
echo "Copied upstream releng profile into $TARGET"
echo "Next: review packages, desktop configs, profile metadata and permissions."
