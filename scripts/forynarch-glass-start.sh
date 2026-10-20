#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  '') ;;
  --vm-renderer) export LIBGL_ALWAYS_SOFTWARE=1 QSG_RHI_BACKEND=opengl ;;
  *) echo 'Usage: forynarch-glass-start [--vm-renderer]' >&2; exit 2 ;;
esac
[[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]] || exit 1
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ -f "$config_home/quickshell/forynarch/shaders/glass.frag.qsb" ]] || { echo 'Compiled glass shader missing.' >&2; exit 1; }
[[ -f "$config_home/quickshell/forynarch/shaders/motion.frag.qsb" ]] || { echo 'Compiled motion shader missing.' >&2; exit 1; }
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$state_home/forynarch"
export QS_NO_RELOAD_POPUP=1
exec qs --no-duplicate --config forynarch
