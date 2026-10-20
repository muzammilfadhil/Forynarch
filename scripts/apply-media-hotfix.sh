#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mode=check;desktop_only=false
for argument in "$@";do
  case "$argument" in --apply) mode=apply;; --check) mode=check;; --desktop-only) desktop_only=true;; *) echo 'Usage: bash apply.sh [--check|--apply] [--desktop-only]' >&2;exit 2;;esac
done
cd "$bundle"
sha256sum --check --quiet SHA256SUMS
echo 'Forynarch R5.8.7: Mudil native controls, playback clock, timed lyrics and app identity.'
echo 'Updates Mudil Music only if already installed. Existing web-app accounts and browser profiles are retained.'
if [[ "$mode" == check ]];then echo 'Use --apply to install. Sign out and back in afterwards.';exit 0;fi
[[ $(id -u) != 0 ]] || { echo 'Run this as your normal desktop user, without sudo.' >&2;exit 1; }
grep -q '^ID=forynarch$' /etc/os-release || { echo 'Run this patch on Forynarch.' >&2;exit 1; }
[[ ! -d /run/archiso || "$desktop_only" == true ]] || { echo 'Boot installed Forynarch before applying this patch.' >&2;exit 1; }
[[ $(pacman -Q hyprland) == "$(cat "$bundle/hyprland-version.txt")" ]] || {
  echo 'The titlebar plugin requires the exact Hyprland package recorded in hyprland-version.txt. No files were changed.' >&2;exit 1;
}
patch_id="r587-$(date -u +%Y%m%dT%H%M%SZ)"
sudo -v
sudo python "$bundle/patch.py" system "$bundle" "$patch_id"
python "$bundle/patch.py" user "$bundle" "$patch_id"
if [[ "$desktop_only" == false ]] && installed="$(pacman -Q mudilmusic 2>/dev/null)";then
  version="${installed#mudilmusic }"
  if (( $(vercmp "$version" 3.9.0-3) < 0 ));then
    sudo pacman -U --needed "$bundle/packages/mudilmusic-3.9.0-3-x86_64.pkg.tar.zst"
  fi
fi
forynarch-webapp-assets refresh-missing || echo 'Some site icons could not be retrieved. Existing icons and accounts were retained.'
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]];then hyprctl reload || true;fi
echo "Installed. Backups: $HOME/.local/state/forynarch/patches/$patch_id and /var/lib/forynarch/patches/$patch_id"
echo 'Sign out and sign back in to load the new titlebar plugin and shell. Reopen Mudil Music to use its corrected playback clock.'
echo 'No ISO was built.'
