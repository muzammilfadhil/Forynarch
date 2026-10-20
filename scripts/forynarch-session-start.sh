#!/usr/bin/env bash
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]] || exit 1
exec 9>"$XDG_RUNTIME_DIR/forynarch-session.lock"
flock -n 9 || exit 0
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
forynarch-audio-start &
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
forynarch-files --prepare
forynarch-system initialize
forynarch-motion restore
forynarch-workspace refresh
shell_choice=classic
[[ ! -f "$config_home/forynarch/desktop-shell" ]] || read -r shell_choice < "$config_home/forynarch/desktop-shell"
if [[ "$shell_choice" == glass ]] && command -v qs >/dev/null &&
   [[ -f "$config_home/quickshell/forynarch/shaders/glass.frag.qsb" && -f "$config_home/quickshell/forynarch/shaders/motion.frag.qsb" ]]; then
  renderer_args=()
  # Explicit VM compatibility path; physical hardware keeps its native renderer.
  if [[ -r /sys/class/dmi/id/product_name ]] && grep -qi virtualbox /sys/class/dmi/id/product_name; then
    renderer_args+=(--vm-renderer)
  fi
  forynarch-glass-start "${renderer_args[@]}" &
elif ! pgrep -u "$(id -u)" -x waybar >/dev/null; then
  waybar --config "$config_home/waybar/config.jsonc" --style "$config_home/waybar/style.css" &
fi
forynarch-notifications prepare
if ! pgrep -u "$(id -u)" -x mako >/dev/null; then mako & fi
( for _ in {1..15};do forynarch-notifications initialize >/dev/null 2>&1 && break;sleep 0.2;done ) &
forynarch-wallpaper restore
if ! pgrep -u "$(id -u)" -x nm-applet >/dev/null; then nm-applet --indicator & fi
systemctl --user start hyprpolkitagent.service
# No power tuning, trusted-drive automount or developer services enabled here.
