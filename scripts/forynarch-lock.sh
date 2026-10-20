#!/usr/bin/env bash
set -euo pipefail
if [[ -d /run/archiso ]];then
  exec notify-send 'Lock unavailable' 'The disposable Live user has no password. Installed sessions support locking.'
fi
if pgrep -u "$(id -u)" -x hyprlock >/dev/null;then exit 0;fi
config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf"
[[ -f "$config" ]] || config=/usr/share/forynarch/hyprlock.conf
if [[ -r /sys/class/dmi/id/product_name ]] && grep -qi virtualbox /sys/class/dmi/id/product_name;then
  runtime_config="$(mktemp "${XDG_RUNTIME_DIR:?}/forynarch-lock.XXXXXXXX")"
  trap 'rm -f -- "$runtime_config"' EXIT
  printf 'source = %s\nanimations {\n    enabled = false\n}\n' "$config" > "$runtime_config"
  hyprlock --config "$runtime_config"
  exit 0
fi
exec hyprlock --config "$config"
