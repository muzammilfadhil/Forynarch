#!/usr/bin/env bash
# Creates only new files under out/qa-*; never attaches a host block device.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/arch-environment.sh
source "$ROOT/scripts/arch-environment.sh"
if [[ "${1:-}" == --help || $# -eq 0 ]]; then
  echo 'Usage: bash scripts/test-live-vm.sh /absolute/path/to/forynarch.iso'
  echo 'Creates a fresh 40 GiB sparse test disk and isolated UEFI variables.'
  echo 'Boot is interactive. In guest, review/install only virtio-FORYNARCH_QA.'
  exit 0
fi
[[ $# == 1 ]] || exit 2
require_arch_environment
for command in qemu-img qemu-system-x86_64; do command -v "$command" >/dev/null || exit 1; done
iso="$(realpath "$1")"
[[ -f "$iso" && "$iso" == *.iso ]] || exit 2
[[ "$iso" != *,* && "$ROOT" != *,* ]] || { echo 'QEMU paths must not contain commas.' >&2; exit 2; }
code=/usr/share/edk2/x64/OVMF_CODE.4m.fd
vars=/usr/share/edk2/x64/OVMF_VARS.4m.fd
[[ -f "$code" && -f "$vars" ]] || { echo 'Review installed edk2-ovmf firmware paths.' >&2; exit 1; }
require_local_destination "$ROOT/out"
mkdir -p "$ROOT/out"
qa="$(mktemp -d "$ROOT/out/qa-XXXXXXXX")"
cp "$vars" "$qa/OVMF_VARS.fd"
qemu-img create -f qcow2 "$qa/disk.qcow2" 40G
acceleration=tcg cpu=max
if [[ -r /dev/kvm && -w /dev/kvm ]]; then acceleration=kvm; cpu=host; fi
echo 'Disposable VM only. No automatic QA success claim; record each guest test.'
qemu-system-x86_64 -machine "q35,accel=$acceleration" -cpu "$cpu" -m 6144 -smp 4 \
  -drive "if=pflash,format=raw,readonly=on,file=$code" \
  -drive "if=pflash,format=raw,file=$qa/OVMF_VARS.fd" \
  -drive "file=$qa/disk.qcow2,format=qcow2,if=virtio,serial=FORYNARCH_QA" \
  -cdrom "$iso" -boot menu=on -nic user,model=virtio-net-pci -device virtio-vga \
  -serial "file:$qa/serial.log"
echo "VM stopped; QA evidence folder: $qa"
