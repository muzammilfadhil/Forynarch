#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/arch-environment.sh
source "$ROOT/scripts/arch-environment.sh"
require_arch_environment

echo 'Forynarch builder evidence (no package installation performed)'
date -u '+recorded_utc=%Y-%m-%dT%H:%M:%SZ'
printf 'kernel_release=%s\n' "$(uname -r)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'source_filesystem=%s\n' "$(findmnt -n -o FSTYPE -T "$ROOT")"
echo 'Repository databases are not refreshed by this script.'
for package in archiso linux hyprland calamares pacman; do
  if pacman -Q "$package" 2>/dev/null; then :; else
    printf '%s: not installed\n' "$package"
  fi
done
echo '--- repository database timestamps (UTC) ---'
for database in /var/lib/pacman/sync/*.db; do
  [[ -f "$database" ]] || continue
  printf '%s ' "${database##*/}"
  TZ=UTC stat -c '%y' "$database"
done
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  printf 'source_revision=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
  if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo 'source_dirty=true'
  else
    echo 'source_dirty=false'
  fi
else
  echo 'source_revision=unavailable'
fi
