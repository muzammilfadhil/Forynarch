#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 2 && -d "$1/etc" && ( "$2" == live || "$2" == target ) ]] || exit 2
root="$(realpath -- "$1")"; mode="$2"
[[ "$root" != / ]] || exit 2
bash "$ROOT/scripts/configure-branding.sh" "$root"
install -Dm644 "$ROOT/config/sddm/10-forynarch.conf" "$root/etc/sddm.conf.d/10-forynarch.conf"
mkdir -p "$root/usr/share/sddm/themes" "$root/etc/systemd/system"
theme="$root/usr/share/sddm/themes/forynarch-kath"
mkdir -p "$theme/Backgrounds"
for item in Main.qml metadata.desktop LICENSE UPSTREAM.md DESIGN.md Components Assets Themes; do
    cp -a "$ROOT/config/sddm/themes/forynarch-kath/$item" "$theme/"
done
install -m644 "$ROOT/assets/wallpapers/navy.svg" "$theme/Backgrounds/forynarch-navy.svg"
rsvg-convert -w 1920 -h 1080 "$ROOT/assets/wallpapers/navy.svg" -o "$theme/Backgrounds/forynarch-navy.png"
install -Dm644 "$ROOT/config/systemd/sddm.service.d/10-forynarch.conf" "$root/etc/systemd/system/sddm.service.d/10-forynarch.conf"
install -Dm644 "$ROOT/config/systemd/logind.conf.d/20-forynarch-session.conf" "$root/etc/systemd/logind.conf.d/20-forynarch-session.conf"
ln -sfn /usr/lib/systemd/system/sddm.service "$root/etc/systemd/system/display-manager.service"
ln -sfn /usr/lib/systemd/system/graphical.target "$root/etc/systemd/system/default.target"
# SDDM owns graphical sessions. A tty login remains a recovery shell.
for home in "$root/etc/skel" "$root/root" "$root/home/liveuser"; do
    [[ -d "$home" ]] || continue
    printf '[[ ! -f ~/.bashrc ]] || source ~/.bashrc\n' > "$home/.bash_profile"
done
rm -f "$root/etc/systemd/system/getty@tty1.service.d/autologin.conf"
if [[ "$mode" == live ]]; then
    install -Dm644 "$ROOT/config/live/sddm-autologin.conf" "$root/etc/sddm.conf.d/20-forynarch-live.conf"
    install -Dm644 "$ROOT/config/live/sddm-prepare.conf" "$root/etc/systemd/system/sddm.service.d/20-forynarch-live.conf"
else
    rm -f "$root/etc/sddm.conf.d/20-forynarch-live.conf" "$root/etc/systemd/system/sddm.service.d/20-forynarch-live.conf"
fi
