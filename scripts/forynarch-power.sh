#!/usr/bin/env bash
# Session/power actions. Called either with no argument (UI power button,
# shows a picker) or with one exact action name (app-search desktop entries),
# in which case the picker step is skipped and only confirmation is shown.
set -euo pipefail
hibernate_supported() {
  local capability
  capability="$(busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null)" || return 1
  [[ "$capability" == 's "yes"' || "$capability" == 's "challenge"' ]]
}
options=('Sign out' 'Sleep' 'Restart' 'Shut down')
if hibernate_supported; then options+=('Hibernate'); fi
# A disposable passwordless Live session must not present a misleading lock.
if [[ ! -d /run/archiso ]]; then options=(Lock "${options[@]}"); fi
choice="${1:-}"
if [[ -z "$choice" ]]; then
  choice="$(printf '%s\n' "${options[@]}" |
    fuzzel --dmenu --prompt='Session  ')" || exit 0
fi
case "$choice" in
  Lock)
    [[ -d /run/archiso ]] && exit 0
    exec hyprlock ;;
  Hibernate)
    if ! hibernate_supported; then
      command -v notify-send >/dev/null && notify-send 'Hibernate unavailable' 'This system has no configured resume storage.'
      exit 0
    fi ;;
esac
case "$choice" in
  'Sign out'|Sleep|Restart|'Shut down'|Hibernate)
    answer="$(printf '%s\n' Cancel "Confirm $choice" |
      fuzzel --dmenu --prompt='Save your work first  ')" || exit 0
    [[ "$answer" == "Confirm $choice" ]] || exit 0
    case "$choice" in
      'Sign out') exec forynarch-logout ;;
      Sleep) exec systemctl suspend ;;
      Hibernate) exec systemctl hibernate ;;
      Restart) exec systemctl reboot ;;
      'Shut down') exec systemctl poweroff ;;
    esac ;;
esac
