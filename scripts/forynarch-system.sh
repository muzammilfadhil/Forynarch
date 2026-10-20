#!/usr/bin/env bash
# On-demand settings backend. No password handling, package installs or sudo.
set -euo pipefail
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
preferences="$config_home/forynarch/system.json"
model=/usr/share/forynarch/system-settings-model.jq
[[ -f "$model" ]] || model="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/system-settings-model.jq"
load_preferences() { if [[ -f "$preferences" ]]; then jq -f "$model" "$preferences"; else printf '{}\n' | jq -f "$model"; fi; }
config_lua() {
  local value="$1"
  printf 'hl.config({general={gaps_in=%s,gaps_out=%s},decoration={rounding=%s}})\n' \
    "$(jq -r .windowGap <<< "$value")" "$(jq -r .screenMargin <<< "$value")" "$(jq -r .cornerRadius <<< "$value")"
  for profile in Tiled Floating;do
    local focused floating
    focused=293b5f;floating=false
    [[ "$profile" != Floating ]] || floating=true
    if [[ $(jq -r ".focus$profile" <<< "$value") == true ]];then focused=$(jq -r '.focusColor|ltrimstr("#")' <<< "$value");fi
    printf 'hl.window_rule({name="forynarch-focus-%s",match={float=%s},border_color="rgba(%sff) rgba(293b5fff)"})\n' "$profile" "$floating" "$focused"
  done
  printf 'hl.config({debug={vfr=%s,overlay=%s},misc={vrr=%s},input={kb_layout="%s",repeat_rate=%s,repeat_delay=%s,sensitivity=%s,touchpad={natural_scroll=%s}}})\n' \
    "$(jq -r .vfr <<< "$value")" "$(jq -r .fpsOverlay <<< "$value")" "$(jq -r .vrr <<< "$value")" \
    "$(jq -r .keyboardLayout <<< "$value")" "$(jq -r .repeatRate <<< "$value")" "$(jq -r .repeatDelay <<< "$value")" \
    "$(jq -r .sensitivity <<< "$value")" "$(jq -r .naturalScroll <<< "$value")"
}
apply_idle() {
  local value="$1" idle_file lock blank sleep_after
  idle_file="$config_home/hypr/forynarch-idle.conf"
  lock="$(jq -r .idleLock <<< "$value")"; blank="$(jq -r .idleBlank <<< "$value")"; sleep_after="$(jq -r .idleSleep <<< "$value")"
  mkdir -p -- "$config_home/hypr" || return 1
  pending="$(mktemp "$config_home/hypr/.idle.XXXXXXXX")" || return 1
  {
    printf 'general {\n  ignore_dbus_inhibit = false\n  ignore_systemd_inhibit = false\n  after_sleep_cmd = hyprctl dispatch "hl.dsp.dpms({action=\\"enable\\"})"\n}\n'
    if [[ "$lock" != 0 && ! -d /run/archiso ]]; then
      printf 'listener {\n  timeout = %s\n  on-timeout = forynarch-hotkey lock\n}\n' "$lock"
    fi
    if [[ "$blank" != 0 ]]; then
      printf 'listener {\n  timeout = %s\n  on-timeout = hyprctl dispatch "hl.dsp.dpms({action=\\"disable\\"})"\n  on-resume = hyprctl dispatch "hl.dsp.dpms({action=\\"enable\\"})"\n}\n' "$blank"
    fi
    if [[ "$sleep_after" != 0 ]]; then
      printf 'listener {\n  timeout = %s\n  on-timeout = systemctl suspend\n}\n' "$sleep_after"
    fi
  } > "$pending" || return 1
  mv -- "$pending" "$idle_file" || return 1
  systemctl --user daemon-reload || return 1
  if [[ "$blank" == 0 && "$sleep_after" == 0 && ( "$lock" == 0 || -d /run/archiso ) ]]; then systemctl --user stop forynarch-idle.service;
  else systemctl --user restart forynarch-idle.service; fi
}
case "${1:-status}" in
  status)
    prefs="$(load_preferences)"
    monitors="$(hyprctl -j monitors all)"
    network='[]'; wifi=false; network_manager=false
    if command -v nmcli >/dev/null && [[ "$(nmcli -t -f RUNNING general 2>/dev/null)" == running ]]; then
      network_manager=true
      network="$(nmcli -t -f DEVICE,TYPE,STATE device status | jq -Rsc 'split("\n") | map(select(length>0) | split(":") | {name:.[0],type:.[1],state:.[2]})')"
      [[ "$(nmcli radio wifi)" != enabled ]] || wifi=true
    fi
    audio='[]'
    if command -v pw-dump >/dev/null; then
      if ! audio="$(pw-dump 2>/dev/null | jq '[.[] | select(.type=="PipeWire:Interface:Node") | .info.props as $p | select($p["media.class"]=="Audio/Sink" or $p["media.class"]=="Audio/Source") | {id:.id,type:$p["media.class"],name:($p["node.description"]//$p["node.name"])}]')"; then audio='[]'; fi
    fi
    batteries='[]'
    for battery in /sys/class/power_supply/*; do
      [[ -f "$battery/type" && "$(cat "$battery/type")" == Battery ]] || continue
      batteries="$(jq --arg name "${battery##*/}" --arg status "$(cat "$battery/status")" --argjson capacity "$(cat "$battery/capacity")" '.+[{name:$name,status:$status,capacity:$capacity}]' <<< "$batteries")"
    done
    live=false; [[ ! -d /run/archiso ]] || live=true
    bluetooth=false; command -v bluetoothctl >/dev/null && bluetooth=true
    notifications=false; dnd=false
    if modes="$(makoctl mode 2>/dev/null)"; then
      notifications=true
      while IFS= read -r mode; do [[ "$mode" != do-not-disturb ]] || dnd=true; done <<< "$modes"
    fi
    display_preview='{"preview":false,"deadline":0}'
    if command -v forynarch-display >/dev/null; then display_preview="$(forynarch-display status)"; fi
    backlight=false; brightness=0
    for node in /sys/class/backlight/*; do
      [[ -d "$node" ]] || continue
      backlight=true
      current="$(cat "$node/brightness")"; maximum="$(cat "$node/max_brightness")"
      if [[ "$current" =~ ^[0-9]+$ && "$maximum" =~ ^[1-9][0-9]*$ ]]; then brightness=$((current*100/maximum)); fi
      break
    done
    memory="$(awk '/MemTotal:/ {total=$2*1024} /MemAvailable:/ {available=$2*1024} END {printf "{\"total\":%.0f,\"used\":%.0f}",total,total-available}' /proc/meminfo)"
    processor="$(awk -F ': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"
    kernel="$(uname -r)"
    pairing=false; command -v forynarch-bluetooth-pair >/dev/null && pairing=true
    copied=false; mountpoint -q /run/archiso/copytoram && copied=true
    jq -n --argjson pairing "$pairing" --argjson copied "$copied" --argjson preferences "$prefs" --argjson monitors "$monitors" --argjson network "$network" --argjson wifi "$wifi" \
      --argjson audio "$audio" --argjson batteries "$batteries" --argjson live "$live" --argjson bluetooth "$bluetooth" --argjson backlight "$backlight" --argjson brightness "$brightness" --argjson networkManager "$network_manager" --argjson displayPreview "$display_preview" --argjson memory "$memory" --arg processor "$processor" --arg kernel "$kernel" --argjson notifications "$notifications" --argjson dnd "$dnd" \
      '{preferences:$preferences,monitors:$monitors,network:$network,wifi:$wifi,audio:$audio,batteries:$batteries,live:$live,bluetooth:$bluetooth,bluetoothPairing:$pairing,liveImageCopiedToRam:$copied,backlight:$backlight,brightness:$brightness,networkManager:$networkManager,displayPreview:$displayPreview,memory:$memory,processor:$processor,kernel:$kernel,notifications:$notifications,dnd:$dnd}' ;;
  set)
    [[ $# == 3 ]] || exit 2
    key="$2"; case "$key" in vfr|fpsOverlay|vrr|naturalScroll|sensitivity|keyboardLayout|repeatRate|repeatDelay|idleLock|idleBlank|idleSleep|windowGap|screenMargin|cornerRadius|focusTiled|focusFloating|focusColor) ;; *) exit 2 ;; esac
    mkdir -p -- "$config_home/forynarch" "$config_home/hypr"
    exec 9>"$config_home/forynarch/system.lock"; flock -x 9
    prefs="$(load_preferences)"
    previous_preferences="$prefs"
    if [[ "$key" == keyboardLayout || "$key" == focusColor ]]; then prefs="$(jq --arg key "$key" --arg value "$3" '.[$key]=$value' <<< "$prefs")";
    else prefs="$(jq --arg key "$key" --argjson value "$3" '.[$key]=$value' <<< "$prefs")"; fi
    prefs="$(jq -f "$model" <<< "$prefs")"
    if [[ "$key" == idleLock && -d /run/archiso && "$3" != 0 ]]; then echo 'Automatic locking is unavailable for the passwordless Live user.' >&2; exit 1; fi
    lua="$(config_lua "$prefs")"
    hyprctl eval "$lua"
    case "$key" in idle*)
      if ! apply_idle "$prefs"; then
        apply_idle "$previous_preferences" || true
        hyprctl eval "$(config_lua "$previous_preferences")" >/dev/null || true
        echo 'Idle service could not apply the policy. Previous preferences were retained.' >&2
        exit 1
      fi
      ;;
    esac
    pending="$(mktemp "$config_home/forynarch/.system.XXXXXXXX")"; printf '%s\n' "$prefs" > "$pending"; mv -- "$pending" "$preferences"
    pending="$(mktemp "$config_home/hypr/.system-settings.XXXXXXXX")"; printf '%s\n' "$lua" > "$pending"; mv -- "$pending" "$config_home/hypr/system-settings.lua"
    ;;
  preferences) [[ $# == 1 ]] || exit 2; load_preferences ;;
  initialize)
    [[ ! -f "$preferences" ]] || apply_idle "$(load_preferences)" ;;
  notifications)
    [[ $# == 2 && "$2" =~ ^(on|off)$ ]] || exit 2
    exec forynarch-notifications dnd "$2" ;;
  wifi)
    [[ $# == 2 && "$2" =~ ^(on|off)$ ]] || exit 2
    nmcli radio wifi "$2" ;;
  connections)
    if command -v nm-connection-editor >/dev/null; then exec nm-connection-editor; fi
    exec forynarch-terminal --title=Network nmtui ;;
  audio-default)
    [[ $# == 2 && "$2" =~ ^[0-9]+$ ]] || exit 2
    pw-dump | jq -e --argjson id "$2" 'any(.[]; .id==$id and (.info.props["media.class"]=="Audio/Sink" or .info.props["media.class"]=="Audio/Source"))' >/dev/null
    exec wpctl set-default "$2" ;;
  microphone-volume)
    [[ $# == 2 && "$2" =~ ^(0|[1-9][0-9]?|100)$ ]] || exit 2
    exec wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$2%" ;;
  microphone-mute) [[ $# == 1 ]] || exit 2; exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
  brightness)
    [[ $# == 2 && "$2" =~ ^([1-9]|[1-9][0-9]|100)$ ]] || exit 2
    exec brightnessctl --class=backlight set "$2%" ;;
  bluetooth-pair)
    [[ $# == 2 && "$2" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || exit 2
    exec forynarch-settings Bluetooth ;;
  bluetooth-manager) exec forynarch-settings Bluetooth ;;
  *) exit 2 ;;
esac
