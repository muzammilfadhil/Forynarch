#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 1 && -d "$1/etc" ]] || exit 2
root="$(realpath -- "$1")"; [[ "$root" != / ]] || exit 2
release="$root/etc/os-release"
image_metadata=""
if [[ -e "$release" ]]; then
    case "$(realpath -- "$release")" in "$root/"*) ;; *) exit 2 ;; esac
    image_metadata="$(sed -n '/^IMAGE_ID=/p; /^IMAGE_VERSION=/p' "$release")"
fi
[[ ! -L "$release" ]] || rm -f -- "$release"
install -m644 "$ROOT/config/os-release" "$release"
[[ -z "$image_metadata" ]] || printf '%s\n' "$image_metadata" >> "$release"
pacman_config="$root/etc/pacman.conf"
if [[ -f "$pacman_config" ]] && ! grep -Eq '^NoUpgrade[[:space:]]*=.*\betc/os-release\b' "$pacman_config"; then
    grep -qx '\[options\]' "$pacman_config" || exit 2
    sed -i '/^\[options\]$/a NoUpgrade = etc/os-release' "$pacman_config"
fi
for destination in \
    usr/share/forynarch/branding/logo.svg \
    usr/share/icons/Forynarch/scalable/apps/forynarch.svg \
    usr/share/icons/Forynarch/scalable/places/distributor-logo.svg \
    usr/share/icons/hicolor/scalable/apps/forynarch.svg \
    usr/share/pixmaps/forynarch.svg; do
    install -Dm644 "$ROOT/assets/branding/logo.svg" "$root/$destination"
done
if command -v rsvg-convert >/dev/null; then
    raster="$root/usr/share/forynarch/branding/logo.png"
    rsvg-convert -w 112 -h 112 "$ROOT/assets/branding/logo.svg" -o "$raster"
    if command -v chafa >/dev/null;then
      chafa --format symbols --symbols vhalf --colors full --fg-only --size 20x10 "$raster" > "$root/usr/share/forynarch/branding/terminal-logo.ansi"
    fi
fi
