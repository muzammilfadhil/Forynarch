#!/usr/bin/env bash
# Install source + compiled assets into a disposable Live session only.
set -euo pipefail
[[ "${1:-}" == --approve-live-preview && $# == 1 ]] || { echo 'Usage: install-glass-preview.sh --approve-live-preview'; exit 2; }
[[ "$(id -u)" == 0 && -d /run/archiso ]] || { echo 'Disposable Archiso Live required.' >&2; exit 1; }
[[ "$(id -u liveuser)" == 1000 && "$(getent passwd liveuser | cut -d: -f6)" == /home/liveuser ]] || exit 1
[[ "$(pacman -Q quickshell | awk '{print $2}')" == 0.3.2-1 ]] || { echo 'Review installed Quickshell release.' >&2; exit 1; }
[[ "$(pacman -Q hyprland | awk '{print $2}')" == 0.56.2-4 ]] || { echo 'Review installed Hyprland release.' >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/scripts/build-glass-shader.sh"
destination=/home/liveuser/.config/quickshell/forynarch
backup="$(mktemp -d /tmp/forynarch-glass-backup.XXXXXXXX)"
wallpaper=/usr/share/backgrounds/forynarch/navy.svg
[[ ! -f "$wallpaper" ]] || cp "$wallpaper" "$backup/navy.svg"
install -Dm644 "$ROOT/assets/wallpapers/navy.svg" "$wallpaper"
if [[ -d "$destination" ]]; then
  cp -a "$destination" "$backup/"
fi
for component in gtk-3.0 fuzzel alacritty mako; do
  config_dir="/home/liveuser/.config/$component"
  [[ ! -d "$config_dir" ]] || cp -a "$config_dir" "$backup/"
  mkdir -p "$config_dir"
  cp -a "$ROOT/config/$component/." "$config_dir/"
  chown -R liveuser:liveuser "$config_dir"
done
mkdir -p "$destination"
cp -a "$ROOT/config/quickshell/forynarch/." "$destination/"
install -m644 "$ROOT/out/glass-shaders/glass.frag.qsb" "$destination/shaders/glass.frag.qsb"
install -m644 "$ROOT/out/glass-shaders/motion.frag.qsb" "$destination/shaders/motion.frag.qsb"
install -m644 "$ROOT/out/glass-shaders/liquid.frag.qsb" "$destination/shaders/liquid.frag.qsb"
chown -R liveuser:liveuser "$destination"
install -m755 "$ROOT/scripts/forynarch-glass-start.sh" /usr/local/bin/forynarch-glass-start
install -m755 "$ROOT/scripts/forynarch-launcher.sh" /usr/local/bin/forynarch-launcher
hypr_config=/home/liveuser/.config/hypr/hyprland.lua
if [[ -f "$hypr_config" ]]; then
  cp "$hypr_config" "$backup/hyprland.lua"
  sed -i -E 's/^(local menu[[:space:]]*=[[:space:]]*)"fuzzel"/\1"forynarch-launcher"/' "$hypr_config"
  chown liveuser:liveuser "$hypr_config"
fi
echo 'Glass preview installed. From the desktop: forynarch-glass-start [--vm-renderer]'
echo 'After confirming startup, stop Waybar to avoid two panels. Existing applications stay running.'
