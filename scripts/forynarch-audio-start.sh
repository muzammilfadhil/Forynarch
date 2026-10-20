#!/usr/bin/env bash
set -euo pipefail
[[ $(id -u) != 0 && -n ${XDG_RUNTIME_DIR:-} ]] || exit 1
# Socket activation alone does not guarantee that the ALSA session manager ran.
systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service
for _ in {1..12}; do
  if pactl info >/dev/null 2>&1; then exit 0; fi
  sleep 0.5
done
echo 'Audio services did not become ready. Run: systemctl --user status pipewire pipewire-pulse wireplumber' >&2
exit 1
