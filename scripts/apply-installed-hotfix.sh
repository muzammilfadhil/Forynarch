#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mode=check;desktop_only=false
for argument in "$@";do
  case "$argument" in --apply) mode=apply;; --check) mode=check;; --desktop-only) desktop_only=true;; *) echo 'Usage: bash apply.sh [--check|--apply] [--desktop-only]' >&2;exit 2;;esac
done
cd "$bundle"
sha256sum --check --quiet SHA256SUMS
echo 'Forynarch R5.8.6 installed-system patch'
echo 'Right-aligned controls; floating titlebars; audio startup/firmware; read-only encrypted drives; Windows letters; Kath lock; player timeline sync.'
echo 'The full patch installs yay-bin and Google Chrome from AUR, with Git/base-devel prerequisites. Existing browser profiles are retained.'
echo 'No partitioning, formatting, EFI changes or automatic drive mounting.'
if [[ "$mode" == check ]];then echo 'Review only. Use --apply to install; --desktop-only skips all package/browser installs.';exit 0;fi
[[ $(id -u) != 0 ]] || { echo 'Run this as your normal Forynarch desktop user, without sudo.' >&2;exit 1; }
if [[ ! -f /etc/os-release ]] || ! grep -q '^ID=forynarch$' /etc/os-release;then
  echo 'Run this patch on your installed Forynarch system.' >&2;exit 1
fi
[[ ! -d /run/archiso || "$desktop_only" == true ]] || { echo 'Boot installed Forynarch before applying this patch.' >&2;exit 1; }
patch_id="r586-$(date -u +%Y%m%dT%H%M%SZ)"
sudo -v
sudo python "$bundle/patch.py" system "$bundle" "$patch_id"
python "$bundle/patch.py" user "$bundle" "$patch_id"
systemctl --user daemon-reload
forynarch-audio-start || echo 'Audio is not ready yet. Firmware installation and a reboot may be needed.'
if [[ -f "$bundle/windows-drives.json" ]];then forynarch-drives merge "$bundle/windows-drives.json";fi
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' || true
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]];then hyprctl reload || true;fi
echo "Desktop patch installed. Backups: $HOME/.local/state/forynarch/patches/$patch_id and /var/lib/forynarch/patches/$patch_id"
if [[ "$desktop_only" == false ]];then
  sudo pacman -S --needed sof-firmware alsa-ucm-conf alsa-utils git base-devel
  if ! pacman -Q yay-bin >/dev/null 2>&1 || ! yay --version >/dev/null 2>&1;then
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/forynarch/aur"
    mkdir -p "$cache"
    build="$(mktemp -d "$cache/yay-bin.XXXXXXXX")"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build/source"
    (cd "$build/source";cat PKGBUILD;makepkg --syncdeps --install --needed)
  fi
  yay -S --needed -- google-chrome
  forynarch-default-apps set browser google-chrome.desktop
  echo 'Google Chrome is now the default browser. New Chrome web apps keep separate account profiles.'
  forynarch-audio-start || true
  echo 'Restart after installing audio firmware. If pacman reports stale mirrors, complete a normal system update and rerun this patch.'
fi
echo 'Sign out and sign back in to reload the desktop widgets and apply the controls to existing applications.'
echo 'Patch complete. No ISO was built.'
