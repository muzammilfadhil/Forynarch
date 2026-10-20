#!/usr/bin/env bash
# Launch the standard partition editor as the desktop user. No disk arguments.
set -euo pipefail
export LC_ALL=C.UTF-8
case "${1:-open}" in
  status)
    [[ $# == 1 ]] || exit 2
    if command -v partitionmanager >/dev/null 2>&1; then
      printf '{"available":true,"name":"KDE Partition Manager"}\n'
    else
      printf '{"available":false,"name":"KDE Partition Manager"}\n'
    fi
    ;;
  open)
    [[ $# -le 1 ]] || { echo 'Disk arguments are not accepted.' >&2; exit 2; }
    [[ $(id -u) != 0 ]] || { echo 'Open Partition Manager from your desktop session.' >&2; exit 1; }
    command -v partitionmanager >/dev/null 2>&1 || { echo 'KDE Partition Manager is not installed in this image.' >&2; exit 1; }
    theme=/usr/share/forynarch/partition-manager.qss
    if [[ -f $theme ]]; then
      exec partitionmanager -stylesheet "$theme"
    fi
    exec partitionmanager
    ;;
  *) echo 'Usage: forynarch-partitions [status|open]' >&2; exit 2 ;;
esac
