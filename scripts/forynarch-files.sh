#!/usr/bin/env bash
set -euo pipefail
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
# Initialize conventional user folders only when no user configuration exists.
if [[ ! -f "$config_home/user-dirs.dirs" ]]; then
  mkdir -p -- "$config_home"
  for folder in Desktop Downloads Documents Music Pictures Videos Templates Public; do
    mkdir -p -- "$HOME/$folder"
  done
  cat > "$config_home/user-dirs.dirs" <<'FOLDERS'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
FOLDERS
fi
[[ "${1:-}" != --prepare ]] || exit 0
[[ $# != 0 ]] || set -- "$HOME"
exec gio open "$@"
