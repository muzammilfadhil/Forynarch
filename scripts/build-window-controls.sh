#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${1:-$root/out/window-controls}"
mkdir -p "$destination"
read -r -a hyprland_flags <<< "$(pkg-config --cflags hyprland)"
g++ -std=c++26 -O2 -shared -fPIC "${hyprland_flags[@]}" \
    "$root/native/window-controls/main.cpp" -o "$destination/forynarch-window-controls.so"
pacman -Q hyprland > "$destination/hyprland-version.txt"
