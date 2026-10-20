#!/usr/bin/env bash
set -euo pipefail
root="${1:-/}"
[[ $# -le 1 && -d "$root/usr/share/applications" ]] || exit 2
wallpaper_plugin="$root/usr/lib/thunarx-3/thunar-wallpaper-plugin.so"
if [[ -f "$wallpaper_plugin" && ! -L "$wallpaper_plugin" ]];then
    mv -f -- "$wallpaper_plugin" "$wallpaper_plugin.disabled"
fi
destination="$root/usr/local/share/applications"
mkdir -p "$destination"
for source in "$root"/usr/share/applications/*.desktop; do
    [[ -f "$source" ]] || continue
    name="${source##*/}"
    case "$name" in
        Alacritty.desktop)
            awk '
                /^\[/ {desktop=($0=="[Desktop Entry]")}
                desktop && /^Exec=/ {print "Exec=forynarch-terminal"; next}
                desktop && /^Icon=/ {print "Icon=utilities-terminal"; next}
                {print}
            ' "$source" > "$destination/$name" ;;
        thunar.desktop|org.xfce.Thunar.desktop|Thunar.desktop)
            awk '
                /^\[/ {desktop=($0=="[Desktop Entry]")}
                desktop && /^(Name|GenericName|Comment|Icon)(\[[^]]+\])?=/ {next}
                desktop && /^Exec=/ {print "Exec=forynarch-file-manager %U"; next}
                desktop && /^DBusActivatable=/ {print "DBusActivatable=false"; next}
                {print}
                $0=="[Desktop Entry]" {print "Name=File Manager\nGenericName=File Manager\nComment=Browse files, folders and drives\nIcon=system-file-manager"}
            ' "$source" > "$destination/$name" ;;
        thunar-settings.desktop|org.xfce.thunar-settings.desktop)
            cat > "$destination/$name" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=File Manager Settings
Comment=Choose how files and folders behave
Exec=forynarch-settings Files
Icon=preferences-desktop
Categories=Settings;DesktopSettings;
DESKTOP
            ;;
        thunar-bulk-rename.desktop|org.xfce.thunar-bulk-rename.desktop)
            awk '
                /^\[/ {desktop=($0=="[Desktop Entry]")}
                desktop && /^Icon=/ {next}
                {print}
                $0=="[Desktop Entry]" {print "Icon=edit-rename"}
            ' "$source" > "$destination/$name" ;;
        xfce4-about.desktop|org.xfce.about.desktop|avahi-discover.desktop|bssh.desktop|bvnc.desktop|avahi-ssh.desktop|avahi-vnc.desktop|avahi-ssh-server-browser.desktop|avahi-vnc-server-browser.desktop)
            printf '[Desktop Entry]\nType=Application\nName=Hidden system utility\nHidden=true\nNoDisplay=true\n' > "$destination/$name" ;;
    esac
done
if command -v update-desktop-database >/dev/null; then update-desktop-database "$destination"; fi
