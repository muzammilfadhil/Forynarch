#!/usr/bin/env bash
# Already authorized disposable Live preview only. No package/service installs.
set -euo pipefail
[[ "${1:-}" == --approve-live-preview && $# == 1 ]] || { echo 'Usage: install-settings-preview.sh --approve-live-preview' >&2; exit 2; }
[[ "$(id -u)" == 0 && -d /run/archiso ]] || { echo 'Disposable Archiso Live required.' >&2; exit 1; }
[[ "$(id -u liveuser)" == 1000 && "$(getent passwd liveuser | cut -d: -f6)" == /home/liveuser ]] || exit 1
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python "$ROOT/scripts/hotkeys.py" --check
backup="$(mktemp -d /tmp/forynarch-settings-backup.XXXXXXXX)"
cp -a /home/liveuser/.config/hypr "$backup/"
cp -a /home/liveuser/.config/quickshell/forynarch "$backup/"
cp -a "$ROOT/config/quickshell/forynarch/." /home/liveuser/.config/quickshell/forynarch/
cp -a "$ROOT/config/quickshell/forynarch-installer" /home/liveuser/.config/quickshell/
bash "$ROOT/scripts/build-installer-shader.sh" /home/liveuser/.config/quickshell/forynarch-installer/shaders
install -m755 "$ROOT/scripts/forynarch-installer-info.sh" /usr/local/bin/forynarch-installer-info
install -m755 "$ROOT/scripts/forynarch-installer-review.sh" /usr/local/bin/forynarch-installer-review
install -m644 "$ROOT/scripts/installer-review.jq" /usr/share/forynarch/installer-review.jq
install -m644 "$ROOT/packages/driver-catalog.json" /usr/share/forynarch/driver-catalog.json
install -m644 "$ROOT/config/hypr/bindings.lua" /home/liveuser/.config/hypr/bindings.lua
install -Dm644 "$ROOT/config/systemd/user/forynarch-idle.service" /home/liveuser/.config/systemd/user/forynarch-idle.service
install -m644 "$ROOT/scripts/system-settings-model.jq" /usr/share/forynarch/system-settings-model.jq
install -m644 "$ROOT/config/forynarch/hotkeys.txt" /usr/share/forynarch/hotkeys.txt
install -m644 "$ROOT/config/forynarch/partition-manager.qss" /usr/share/forynarch/partition-manager.qss
for helper in system display hotkey window-switcher workspace settings shortcuts storage setup partitions live-diagnostics; do
  install -m755 "$ROOT/scripts/forynarch-$helper.sh" "/usr/local/bin/forynarch-$helper"
done
install -m644 "$ROOT/config/applications/forynarch-settings.desktop" /usr/share/applications/forynarch-settings.desktop
install -m644 "$ROOT/config/applications/forynarch-install.desktop" /usr/share/applications/forynarch-install.desktop
for model in storage-inventory storage-plan; do install -m644 "$ROOT/scripts/$model.jq" "/usr/share/forynarch/$model.jq"; done
install -m644 "$ROOT/packages/optional-catalog.yaml" /usr/share/forynarch/optional-catalog.json
install -Dm644 "$ROOT/config/mako/config" /home/liveuser/.config/mako/config
# Add only the module-loading footer; never overwrite the user's current config.
python - /home/liveuser/.config/hypr/hyprland.lua <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
content = path.read_text()
if '"bindings.lua", "system-settings.lua", "monitors.lua"' not in content:
    content += '''
local user_config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
for _, module in ipairs({"bindings.lua", "system-settings.lua", "monitors.lua"}) do
    local path = user_config .. "/hypr/" .. module
    local file = io.open(path, "r")
    if file then file:close(); dofile(path) end
end
'''
    path.write_text(content)
PY
chown -R liveuser:liveuser /home/liveuser/.config/hypr /home/liveuser/.config/quickshell /home/liveuser/.config/systemd /home/liveuser/.config/mako
printf 'Settings preview installed. Backup: %s\n' "$backup"
echo 'No Bluetooth packages installed, no monitor mode changed and no sleep policy enabled.'
