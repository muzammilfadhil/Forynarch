# Convenience commands are restricted to the disposable Live account.
if [[ -d /run/archiso && $USER == liveuser && $EUID == 1000 ]]; then
    function pacman() { command sudo -n /usr/bin/pacman "$@"; }
    function gdisk() { command sudo -n /usr/bin/gdisk "$@"; }
fi
