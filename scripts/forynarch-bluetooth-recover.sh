#!/usr/bin/env bash
set -euo pipefail
[[ $(id -u) == 0 && $# == 0 ]] || { echo 'Use the authenticated Bluetooth recovery action.' >&2;exit 2; }
systemctl start bluetooth.service
rfkill unblock bluetooth
