#!/usr/bin/env bash
# Standalone graphical setup; the confirmed request uses the Live executor.
set -euo pipefail
if [[ ! -d /run/archiso ]]; then
  exec notify-send 'Install Forynarch' 'Boot the Forynarch Live media to install the operating system.'
fi
if ! command -v qs >/dev/null; then
  exec notify-send 'Install Forynarch' 'The installer is unavailable in this image. Use an updated Forynarch Live image.'
fi
if [[ -r /sys/class/dmi/id/product_name ]] && grep -qi virtualbox /sys/class/dmi/id/product_name;then
  export LIBGL_ALWAYS_SOFTWARE=1 QSG_RHI_BACKEND=opengl
fi
# Reuse the existing instance. It has no IPC methods exposing account secrets.
if qs -c forynarch-installer ipc call installer status >/dev/null 2>&1; then exit 0; fi
exec qs -c forynarch-installer
