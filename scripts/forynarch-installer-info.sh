#!/usr/bin/env bash
# Read-only installer inventory. No settings, package or disk changes.
set -euo pipefail
shared=/usr/share/forynarch
[[ -f "$shared/driver-catalog.json" ]] || { echo 'Installer resources are unavailable.' >&2; exit 1; }
[[ $# == 0 ]] || exit 2
graphics() {
  local device class vendor model driver name
  for device in /sys/bus/pci/devices/*; do
    [[ -f "$device/class" ]] || continue
    read -r class < "$device/class"
    [[ $class == 0x03* ]] || continue
    read -r vendor < "$device/vendor"
    read -r model < "$device/device"
    driver=""
    if [[ -L "$device/driver" ]]; then driver="$(readlink -f "$device/driver" || true)"; fi
    case "$vendor" in
      0x8086) name='Intel graphics' ;;
      0x1002) name='AMD graphics' ;;
      0x10de) name='NVIDIA graphics' ;;
      0x15ad) name='VMware graphics adapter' ;;
      *) name='Graphics adapter' ;;
    esac
    jq -cn --arg vendor "$vendor" --arg device "$model" --arg driver "${driver##*/}" --arg name "$name" '{vendor:$vendor,device:$device,driver:$driver,name:$name}'
  done
}
gpus="$(graphics | jq -s .)"
executor=false
if [[ -x /usr/local/libexec/forynarch-install-system && -f "$shared/install_layout.py" && -f "$shared/installer-executor-version" && -f "$shared/SHA256SUMS" && -f "$shared/target-rootfs.tar.zst" ]] &&
    [[ "$(cat "$shared/installer-executor-version")" == 2 && -f "$shared/driver-catalog.json" ]] && cmp -s "$shared/optional-catalog.json" "$shared/optional-catalog.yaml"; then
    executor=true
fi
zones="$(timedatectl list-timezones | jq -Rs 'split("\n")|map(select(length>0))')"
secure_boot=false
secure_boot_variable=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
if [[ -r "$secure_boot_variable" && "$(od -An -t u1 -j4 -N1 "$secure_boot_variable" | tr -d ' ')" == 1 ]];then secure_boot=true;fi
forynarch-storage list | jq --argjson graphics "$gpus" --argjson timezones "$zones" --argjson executor "$executor" --argjson secure_boot "$secure_boot" \
  --slurpfile drivers "$shared/driver-catalog.json" \
  '.+{graphics:$graphics,timezones:$timezones,drivers:$drivers[0],executorAvailable:$executor,secureBootEnabled:$secure_boot}|.software += [{id:"arc",label:"Arc",description:"No supported native Linux release is available.",available:false}]'
