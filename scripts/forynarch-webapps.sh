#!/usr/bin/env bash
set -euo pipefail
umask 077
base="${XDG_DATA_HOME:-$HOME/.local/share}/forynarch/webapps"
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p -- "$base" "$applications"
fail() { printf '{"error":"%s"}\n' "$1";exit 1; }
valid_id() { [[ "$1" =~ ^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$ ]]; }
assets() {
    if [[ -f "$(dirname "$0")/forynarch-webapp-assets.py" ]];then
        python "$(dirname "$0")/forynarch-webapp-assets.py" "$@"
    else
        forynarch-webapp-assets "$@"
    fi
}
browser_command() {
    case "$1" in
        chromium) browser=(chromium);;
        chrome) browser=(google-chrome-stable);;
        vivaldi) browser=(vivaldi-stable);;
        firefox) browser=(firefox);;
        chrome-flatpak)
            browser=(flatpak run --user com.google.Chrome)
            command -v flatpak >/dev/null && flatpak --user info com.google.Chrome >/dev/null 2>&1 || return 1;;
        zen-flatpak)
            browser=(flatpak run --user app.zen_browser.zen)
            command -v flatpak >/dev/null && flatpak --user info app.zen_browser.zen >/dev/null 2>&1 || return 1;;
        *) return 1;;
    esac
    command -v "${browser[0]}" >/dev/null
}
case "${1:-open}" in
    open) exec qs -c forynarch ipc call appearance openWebApps;;
    list)
        browsers=()
        for name in chromium chrome vivaldi firefox chrome-flatpak zen-flatpak; do
            if browser_command "$name";then browsers+=("$name");fi
        done
        browser_json="$(printf '%s\n' "${browsers[@]}" | jq -Rs 'split("\n")|map(select(length>0))')"
        shopt -s nullglob
        files=("$base"/*.json)
        if ((${#files[@]})); then rows="$(jq -s '[.[]|select(.active==true)]' "${files[@]}")";else rows='[]';fi
        jq -cn --argjson browsers "$browser_json" --argjson apps "$rows" '{browsers:$browsers,apps:$apps}' ;;
    create)
        [[ $# == 1 ]] || exit 2
        request="$(head -c 8192)"
        jq -e 'def weburl: test("^https://([A-Za-z0-9.-]+|\\[[0-9A-Fa-f:]+\\])(:[0-9]{1,5})?([/?#][^[:space:]]*)?$");
            type=="object" and (keys==["browser","icon","name","url"]) and all(.[];type=="string") and
            (.name|length>0 and length<=80 and (test("[\u0000-\u001f\u007f\\\\]")|not)) and
            (.url|length<=2048 and weburl) and
            (.icon|length<=2048 and (.=="" or weburl))' <<< "$request" >/dev/null || fail 'Use a name and a valid HTTPS address without credentials.'
        name="$(jq -r .name <<< "$request")";url="$(jq -r .url <<< "$request")";engine="$(jq -r .browser <<< "$request")"
        browser_command "$engine" || fail 'Choose an installed browser. No browser is installed automatically.'
        id="$(cat /proc/sys/kernel/random/uuid)"
        profile="$base/$id";mkdir -m700 -- "$profile"
        icon_url="$(jq -r .icon <<< "$request")"
        icon='applications-internet'
        jq -cn --arg id "$id" --arg name "$name" --arg url "$url" --arg browser "$engine" --arg icon "$icon" --arg iconUrl "$icon_url" '{id:$id,name:$name,url:$url,browser:$browser,icon:$icon,iconUrl:$iconUrl,active:true}' > "$base/$id.json"
        printf '[Desktop Entry]\nType=Application\nName=%s\nComment=Web app with a separate account profile\nExec=forynarch-webapps launch %s\nIcon=%s\nTerminal=false\nCategories=Network;\nStartupNotify=true\n' "$name" "$id" "$icon" > "$applications/forynarch-webapp-$id.desktop"
        assets refresh "$id" || assets sync
        command -v update-desktop-database >/dev/null && update-desktop-database "$applications" 2>/dev/null || true
        printf '{"created":true}\n';;
    launch|remove)
        [[ $# == 2 ]] && valid_id "$2" || exit 2
        metadata="$base/$2.json"
        [[ -f "$metadata" ]] || fail 'This web app could not be found.'
        if [[ "$1" == remove ]];then
            temporary="$(mktemp "$base/.metadata.XXXXXXXX")"
            jq '.active=false' "$metadata" > "$temporary";mv -f -- "$temporary" "$metadata"
            rm -f -- "$applications/forynarch-webapp-$2.desktop"
            assets sync
            printf '{"removed":true,"profileRetained":true}\n';exit 0
        fi
        [[ "$(jq -r .active "$metadata")" == true ]] || exit 1
        assets sync
        engine="$(jq -r .browser "$metadata")";url="$(jq -r .url "$metadata")"
        browser_command "$engine" || fail 'The browser used by this web app is not installed.'
        profile="$base/$2"
        case "$engine" in
            chrome-flatpak) profile="$HOME/.var/app/com.google.Chrome/config/forynarch-webapps/$2";;
            zen-flatpak) profile="$HOME/.var/app/app.zen_browser.zen/config/forynarch-webapps/$2";;
        esac
        mkdir -p -- "$profile"
        chmod 700 -- "$profile"
        if [[ "$engine" == firefox || "$engine" == zen-flatpak ]];then
            exec "${browser[@]}" --no-remote --profile "$profile" --new-window "$url"
        fi
        exec "${browser[@]}" --user-data-dir="$profile" --class="forynarch-webapp-$2" --no-first-run --no-default-browser-check --app="$url" ;;
    *) exit 2;;
esac
