#!/usr/bin/env bash
# Update native background colors only. GTK applications reload them on restart.
set -euo pipefail
[[ $# == 2 && "$1" =~ ^(on|off)$ && "$2" =~ ^(76|84|92)$ ]] || {
  echo 'Usage: forynarch-application-theme on|off 76|84|92' >&2; exit 2;
}
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
alpha="0.$2"
for toolkit in gtk-3.0 gtk-4.0; do
  mkdir -p -- "$config_home/$toolkit"
  pending="$(mktemp "$config_home/$toolkit/.glass.XXXXXXXX")"
  if [[ "$1" == on ]]; then
    cat > "$pending" <<COLORS
/* Generated native glass palette. Text and controls remain opaque. */
@define-color forynarch_window_bg rgba(17,24,35,$alpha);
@define-color forynarch_content_bg transparent;
@define-color forynarch_sidebar_bg rgba(17,29,45,0.35);
@define-color forynarch_toolbar_bg rgba(21,32,49,0.35);
COLORS
  else
    cat > "$pending" <<'COLORS'
/* Opaque native palette. */
@define-color forynarch_window_bg #111823;
@define-color forynarch_content_bg #151e2b;
@define-color forynarch_sidebar_bg #111d2d;
@define-color forynarch_toolbar_bg #152031;
COLORS
  fi
  destination="$config_home/$toolkit/forynarch-glass.css"
  if [[ -f "$destination" ]] && cmp -s "$pending" "$destination"; then rm -- "$pending";
  else mv -- "$pending" "$destination"; fi
done
terminal_config="$config_home/alacritty/alacritty.toml"
if [[ -f "$terminal_config" ]]; then
  pending="$(mktemp "$config_home/alacritty/.glass.XXXXXXXX")"
  terminal_alpha="$alpha"; [[ "$1" != off ]] || terminal_alpha=1.0
  awk -v alpha="$terminal_alpha" '
    /^\[/ {window=($0=="[window]")}
    window && /^[[:space:]]*opacity[[:space:]]*=/ {print "opacity = " alpha; next}
    {print}
  ' "$terminal_config" > "$pending"
  if cmp -s "$pending" "$terminal_config"; then rm -- "$pending";
  else mv -- "$pending" "$terminal_config"; fi
fi
