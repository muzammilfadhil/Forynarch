#!/usr/bin/env bash
set -euo pipefail
destination="${1:?Choose a builder output directory}"
[[ $(pkg-config --modversion hyprland) == 0.56.2 ]] || {
  echo 'Update the reviewed hyprbars pin for this Hyprland SDK before building.' >&2;exit 1;
}
pin=7644cecdb947060682891a0db2a0cdc5c0b9e704
mkdir -p "$destination"
source="$destination/source"
if [[ ! -d "$source/.git" ]];then git clone --no-checkout https://github.com/hyprwm/hyprland-plugins "$source";fi
git -C "$source" fetch --depth 1 origin "$pin"
git -C "$source" checkout --detach "$pin"
python "$(dirname "$0")/patch-titlebar-app-names.py" "$source/hyprbars"
python "$(dirname "$0")/patch-titlebar-damage.py" "$source/hyprbars"
make -C "$source/hyprbars" CXXFLAGS='-O2 -shared -fPIC -std=c++26 -Wno-c++11-narrowing'
install -m755 "$source/hyprbars/hyprbars.so" "$destination/hyprbars.so"
install -m644 "$source/LICENSE" "$destination/LICENSE"
printf '%s\n' "$pin" > "$destination/upstream-commit.txt"
pacman -Q hyprland > "$destination/hyprland-version.txt"
