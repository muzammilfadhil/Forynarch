#!/usr/bin/env bash
# Live-only preview. No package installs and no storage mount/unlock/write actions.
set -euo pipefail
[[ "${1:-}" == --approve-live-preview && $# == 1 ]] || { echo 'Usage: install-files-preview.sh --approve-live-preview' >&2; exit 2; }
[[ "$(id -u)" == 0 && -d /run/archiso ]] || { echo 'Disposable Archiso Live required.' >&2; exit 1; }
[[ "$(id -u liveuser)" == 1000 && "$(getent passwd liveuser | cut -d: -f6)" == /home/liveuser ]] || exit 1
for required in thunar jq udisksctl python glib-compile-schemas; do command -v "$required" >/dev/null; done
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
backup="$(mktemp -d /tmp/forynarch-files-backup.XXXXXXXX)"
for component in gtk-3.0 gtk-4.0 Thunar; do
  original="/home/liveuser/.config/$component"
  [[ ! -d "$original" ]] || cp -a "$original" "$backup/"
done
[[ ! -f /etc/udisks2/mount_options.conf ]] || cp /etc/udisks2/mount_options.conf "$backup/"
[[ ! -f /usr/share/glib-2.0/schemas/90_forynarch.gschema.override ]] || cp /usr/share/glib-2.0/schemas/90_forynarch.gschema.override "$backup/"
mkdir -p /home/liveuser/.config/gtk-3.0 /home/liveuser/.config/Thunar /usr/share/icons
cp -a "$ROOT/config/gtk-3.0/." /home/liveuser/.config/gtk-3.0/
mkdir -p /home/liveuser/.config/gtk-4.0
cp -a "$ROOT/config/gtk-4.0/." /home/liveuser/.config/gtk-4.0/
cp -a "$ROOT/assets/icons/Forynarch" /usr/share/icons/
install -Dm644 "$ROOT/scripts/storage-model.jq" /usr/share/forynarch/storage-model.jq
install -Dm644 "$ROOT/config/applications/forynarch-drives.desktop" /usr/share/applications/forynarch-drives.desktop
install -Dm644 "$ROOT/config/applications/forynarch-settings.desktop" /usr/share/applications/forynarch-settings.desktop
install -Dm644 "$ROOT/config/udisks2/mount_options.conf" /etc/udisks2/mount_options.conf
install -m755 "$ROOT/scripts/forynarch-drives.sh" /usr/local/bin/forynarch-drives
install -m755 "$ROOT/scripts/forynarch-files.sh" /usr/local/bin/forynarch-files
install -m755 "$ROOT/scripts/forynarch-application-theme.sh" /usr/local/bin/forynarch-application-theme
install -m755 "$ROOT/scripts/forynarch-settings.sh" /usr/local/bin/forynarch-settings
install -m644 "$ROOT/config/glib-2.0/90_forynarch.gschema.override" /usr/share/glib-2.0/schemas/90_forynarch.gschema.override
glib-compile-schemas --strict /usr/share/glib-2.0/schemas
hypr_config=/home/liveuser/.config/hypr/hyprland.lua
if [[ -f "$hypr_config" ]]; then
  cp "$hypr_config" "$backup/hyprland.lua"
  sed -i -E 's/^(local fileManager[[:space:]]*=[[:space:]]*)"thunar"/\1"forynarch-files"/' "$hypr_config"
fi
# Merge our actions without discarding the user's other custom actions.
python - "$ROOT/config/Thunar/uca.xml" /home/liveuser/.config/Thunar/uca.xml <<'PY'
import pathlib, sys, xml.etree.ElementTree as ET
source, target = map(pathlib.Path, sys.argv[1:])
root = ET.parse(target).getroot() if target.exists() else ET.Element('actions')
for addition in ET.parse(source).getroot():
    key = addition.findtext('unique-id')
    for old in list(root):
        if old.findtext('unique-id') == key:
            root.remove(old)
    root.append(addition)
ET.ElementTree(root).write(target, encoding='UTF-8', xml_declaration=True)
PY
chown -R liveuser:liveuser /home/liveuser/.config/gtk-3.0 /home/liveuser/.config/gtk-4.0 /home/liveuser/.config/Thunar
printf 'Files preview installed. Backup: %s\n' "$backup"
echo 'Already open Thunar windows keep their loaded theme. Apply on a fresh launch after finishing file operations.'
echo 'No drive was mounted, unlocked, relabeled or formatted. ISO unchanged.'
