#!/usr/bin/env bash
# Stable per-monitor five-slot allocations. No daemon or polling.
set -euo pipefail
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || exit 1
state="$XDG_RUNTIME_DIR/forynarch-active-workspace"
resolve_base() {
  local monitors identity config_home mapping pending
monitors="$(hyprctl -j monitors)" || return 1
identity="$(jq -er '. as $all | first(.[] | select(.focused)) as $focused | $focused | if (.serial // "")!="" and ([ $all[] | select(.serial==$focused.serial) ] | length)==1 then ((.make//"")+":"+(.model//"")+":"+.serial) else .name end' <<< "$monitors")" || return 1
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}/forynarch"
  mkdir -p -- "$config_home"
  mapping="$config_home/monitor-slots.json"
  exec 8>"$config_home/monitor-slots.lock"; flock -x 8
  [[ -f "$mapping" ]] || printf '{}\n' > "$mapping"
jq -e 'type=="object" and all(.[]; type=="number" and .>=0 and .<=100000 and .%5==0 and .==floor) and ([.[]]|unique|length)==length' "$mapping" >/dev/null || return 1
  if ! jq -e --arg key "$identity" 'has($key)' "$mapping" >/dev/null; then
    pending="$(mktemp "$config_home/.monitor-slots.XXXXXXXX")"
    jq --arg key "$identity" '.[$key]=((([.[]]|max)//-5)+5)' "$mapping" > "$pending"
    mv -- "$pending" "$mapping"
  fi
  jq -r --arg key "$identity" '.[$key]' "$mapping"
}
case "${1:-}" in
  refresh)
    active="$(hyprctl -j activeworkspace | sed -n 's/^[[:space:]]*"id":[[:space:]]*\([0-9][0-9]*\),\{0,1\}$/\1/p' | head -1)"
    [[ "$active" =~ ^[0-9]+$ ]] || exit 1
    temporary="$(mktemp "$XDG_RUNTIME_DIR/forynarch-workspace.XXXXXX")"
    printf '%s\n' "$active" > "$temporary"
    mv -f -- "$temporary" "$state"
    pkill -u "$(id -u)" -RTMIN+8 -x waybar || true ;;
  next|previous)
    base="$(resolve_base)"
    active="$(hyprctl -j activeworkspace | jq -r .id)"
    if (( active <= base || active > base+5 )); then active=$((base+1)); fi
    slot=$(((active-base-1)%5+1)); delta=1; [[ "$1" != previous ]] || delta=-1
    slot=$(((slot-1+delta+5)%5+1))
    exec hyprctl dispatch "hl.dsp.focus({workspace=$((base+slot)),on_current_monitor=true})" ;;
  status|focus|move|move-silent)
    slot="${2:-}"
    [[ "$slot" =~ ^[1-5]$ ]] || exit 1
    if [[ "$1" != status ]]; then
      base="$(resolve_base)"; workspace=$((base+slot))
      if [[ "$1" == focus ]]; then exec hyprctl dispatch "hl.dsp.focus({workspace=$workspace,on_current_monitor=true})"; fi
      follow=true; [[ "$1" != move-silent ]] || follow=false
      exec hyprctl dispatch "hl.dsp.window.move({workspace=$workspace,follow=$follow})"
    fi
    active=''
    [[ ! -f "$state" ]] || read -r active < "$state"
    class=inactive
    [[ -z "$active" || "$(((active-1)%5+1))" != "$slot" ]] || class=active
    printf '{"text":"%s","class":"%s","tooltip":"Workspace %s"}\n' "$slot" "$class" "$slot" ;;
  *) exit 1 ;;
esac
