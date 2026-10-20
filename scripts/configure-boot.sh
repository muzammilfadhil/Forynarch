#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 1 && -d "$1/etc" ]] || exit 2
root="$(realpath -- "$1")"; [[ "$root" != / ]] || exit 2
command -v rsvg-convert >/dev/null || { echo 'The builder requires librsvg to render the boot theme.' >&2; exit 1; }
theme="$root/usr/share/plymouth/themes/forynarch"
mkdir -p "$theme" "$root/etc/plymouth"
install -m644 "$ROOT/config/plymouth/forynarch/forynarch.plymouth" "$ROOT/config/plymouth/forynarch/forynarch.script" "$theme/"
for image in mark track fill dot; do
    asset="$ROOT/config/plymouth/forynarch/$image.svg"
    [[ "$image" != mark ]] || asset="$ROOT/assets/branding/logo.svg"
    rsvg-convert "$asset" -o "$theme/$image.png"
done
printf '[Daemon]\nTheme=forynarch\nShowDelay=0\nDeviceTimeout=5\n' > "$root/etc/plymouth/plymouthd.conf"
mkdir -p "$root/etc/mkinitcpio.conf.d"
printf 'COMPRESSION="zstd"\nCOMPRESSION_OPTIONS=(-3)\n' > "$root/etc/mkinitcpio.conf.d/zz-forynarch-compression.conf"
python "$ROOT/scripts/boot_policy.py" root "$root"
python "$ROOT/scripts/grub_theme.py" root "$root"
rsvg-convert -w 32 -h 32 "$ROOT/assets/branding/logo.svg" -o "$root/usr/share/grub/themes/forynarch-particle/icons/forynarch.png"
