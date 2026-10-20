#!/usr/bin/env bash
# Live-only boot setup. Never copy this service into the installed target.
set -euo pipefail
[[ "$(id -u)" == 0 && -d /run/archiso ]] || { echo 'Live Archiso only.' >&2; exit 1; }
plymouth update --status=forynarch-live 2>/dev/null || true
if [[ -f /usr/share/glib-2.0/schemas/90_forynarch.gschema.override ]]; then
  glib-compile-schemas --strict /usr/share/glib-2.0/schemas
fi
if ! id liveuser >/dev/null 2>&1; then
  useradd --create-home --uid 1000 --user-group --groups video,render --shell /bin/zsh liveuser
fi
usermod --shell /bin/zsh liveuser
[[ "$(id -u liveuser)" == 1000 ]] || { echo 'Unexpected liveuser UID.' >&2; exit 1; }
[[ "$(getent passwd liveuser | cut -d: -f6)" == /home/liveuser ]] || exit 1
# Staging helpers can create the home before useradd, which then skips skel.
[[ -d /home/liveuser && ! -L /home/liveuser ]] || exit 1
cp -an /etc/skel/. /home/liveuser/
install -d /home/liveuser/.local/share/sddm
chown -hR liveuser:liveuser -- /home/liveuser

# Live administration stays outside the independently built installed rootfs.
usermod --append --groups wheel liveuser
install -d -m755 /etc/sudoers.d
printf 'liveuser ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/10-forynarch-live
chmod 440 /etc/sudoers.d/10-forynarch-live
visudo -cf /etc/sudoers
passwd -d liveuser
forynarch-desktop-integrate
