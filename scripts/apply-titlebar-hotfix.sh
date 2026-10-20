#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mode=check;desktop_only=false
for argument in "$@";do
  case "$argument" in --apply) mode=apply;; --check) mode=check;; --desktop-only) desktop_only=true;; *) echo 'Usage: bash apply.sh [--check|--apply] [--desktop-only]' >&2;exit 2;;esac
done
cd "$bundle"
sha256sum --check --quiet SHA256SUMS
echo 'Forynarch R5.8.8: bounded titlebar repaint, native app controls and configurable exceptions.'
echo 'Settings > Desktop > Window controls. No packages or ISO build required.'
if [[ "$mode" == check ]];then echo 'Use --apply to install, then sign out and back in.';exit 0;fi
[[ $(id -u) != 0 ]] || { echo 'Run this as your normal desktop user, without sudo.' >&2;exit 1; }
grep -q '^ID=forynarch$' /etc/os-release || { echo 'Run this patch on Forynarch.' >&2;exit 1; }
[[ ! -d /run/archiso || "$desktop_only" == true ]] || { echo 'Boot installed Forynarch before applying this patch.' >&2;exit 1; }
[[ $(pacman -Q hyprland) == "$(cat "$bundle/hyprland-version.txt")" ]] || {
  echo 'The titlebar plugin requires the exact Hyprland package in hyprland-version.txt. No files were changed.' >&2;exit 1;
}
patch_id="r588-$(date -u +%Y%m%dT%H%M%SZ)"
sudo -v
sudo python "$bundle/patch.py" system "$bundle" "$patch_id"
python "$bundle/patch.py" user "$bundle" "$patch_id"
forynarch-titlebars apply
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]];then hyprctl reload || true;fi
echo "Installed. Backups: $HOME/.local/state/forynarch/patches/$patch_id and /var/lib/forynarch/patches/$patch_id"
echo 'Sign out and sign back in to replace the loaded titlebar plugin and refresh Settings. A config reload alone does not activate the repaint fix.'
