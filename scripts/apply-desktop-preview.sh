#!/usr/bin/env bash
# Reversible preview on disposable Archiso RAM filesystems only.
set -euo pipefail
[[ "${1:-}" == --approve-live-preview && $# == 1 ]] || {
  echo 'Usage: bash scripts/apply-desktop-preview.sh --approve-live-preview' >&2; exit 2;
}
[[ "$(id -u)" == 0 && -d /run/archiso ]] || { echo 'Root in disposable Archiso Live required.' >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(id -u liveuser)" == 1000 && "$(getent passwd liveuser | cut -d: -f6)" == /home/liveuser ]] || exit 1
for command in python swaybg hyprctl; do command -v "$command" >/dev/null; done
backup="$(mktemp -d /tmp/forynarch-desktop-backup.XXXXXXXX)"
cp -a /home/liveuser/.config "$backup/"
version="$(pacman -Q hyprland | awk '{print $2}')"
example="$(pacman -Ql hyprland | awk '$2 ~ /\/hyprland\.lua$/ {print $2; exit}')"
mkdir -p /home/liveuser/.config/hypr
python "$ROOT/scripts/automation_support.py" adapt "$example" "$version" /home/liveuser/.config/hypr/hyprland.lua
for directory in alacritty fuzzel mako waybar gtk-3.0 gtk-4.0; do
  cp -a "$ROOT/config/$directory" /home/liveuser/.config/
  chown -R liveuser:liveuser "/home/liveuser/.config/$directory"
done
cp "$ROOT/config/hypr/hyprlock.conf" /home/liveuser/.config/hypr/
chown -R liveuser:liveuser /home/liveuser/.config/hypr
for helper in session-start menu power shortcuts workspace launcher files drives application-theme settings; do
  install -m755 "$ROOT/scripts/forynarch-$helper.sh" "/usr/local/bin/forynarch-$helper"
done
install -Dm644 "$ROOT/assets/wallpapers/navy.svg" /usr/share/backgrounds/forynarch/navy.svg
bash "$ROOT/scripts/install-files-preview.sh" --approve-live-preview
test -r /home/liveuser/.config/alacritty/alacritty.toml
fuzzel --check-config --config=/home/liveuser/.config/fuzzel/fuzzel.ini
printf 'Preview files installed. Existing configuration backup: %s\n' "$backup"
echo 'Reload Hyprland and restart Waybar from the desktop session, or sign out and log in.'
echo 'Live changes are temporary; this does not modify the ISO or an installed target.'
