#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 2 && -d "$1/etc" && ( "$2" == target || "$2" == live ) ]] || exit 2
root="${1%/}";mode="$2"
install -Dm755 "$ROOT/scripts/forynarch-audio-start.sh" "$root/usr/local/bin/forynarch-audio-start"
install -Dm755 "$ROOT/scripts/forynarch-lock.sh" "$root/usr/local/bin/forynarch-lock"
install -Dm644 "$ROOT/config/hypr/hyprlock.conf" "$root/usr/share/forynarch/hyprlock.conf"
controls="${FORYNARCH_WINDOW_CONTROLS_DIR:-}"
titlebars="${FORYNARCH_TITLEBARS_DIR:-}"
if [[ -n "$titlebars" ]];then
  staged_version="$(pacman --root "$root" -Q hyprland 2>/dev/null || true)"
  if [[ -z "$staged_version" && "$mode" == live && ! -d "$root/var/lib/pacman/local" ]]; then
    staged_version="${FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION:-}"
  fi
  [[ -n "$staged_version" && "$staged_version" == "$(cat "$titlebars/hyprland-version.txt")" ]] || { echo 'Rebuild titlebars for the staged Hyprland release.' >&2;exit 1; }
  install -Dm755 "$titlebars/hyprbars.so" "$root/usr/lib/forynarch/hyprbars.so"
  install -Dm644 "$titlebars/LICENSE" "$root/usr/share/licenses/forynarch/hyprbars-BSD-3-Clause.txt"
  install -Dm644 "$titlebars/upstream-commit.txt" "$root/usr/share/forynarch/hyprbars-commit.txt"
  install -Dm644 "$ROOT/config/hypr/titlebars.lua" "$root/etc/skel/.config/hypr/titlebars.lua"
fi
if [[ -n "$controls" ]];then
  [[ -f "$controls/forynarch-window-controls.so" ]] || { echo 'Compiled native window controls are missing.' >&2;exit 1; }
  staged_version="$(pacman --root "$root" -Q hyprland 2>/dev/null || true)"
  [[ -n "$staged_version" ]] || staged_version="${FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION:-}"
  [[ "$staged_version" == "$(cat "$controls/hyprland-version.txt")" ]] || { echo 'Rebuild native window controls for the staged Hyprland release.' >&2;exit 1; }
  install -Dm755 "$controls/forynarch-window-controls.so" "$root/usr/lib/forynarch/forynarch-window-controls.so"
  install -Dm644 "$controls/hyprland-version.txt" "$root/usr/share/forynarch/window-controls-version.txt"
fi
[[ -n "$root" ]] || { echo 'A staged root is required.' >&2;exit 2; }
for helper in file-preferences file-manager desktop-integrate login-users motion emoji emoji-config giphy insert widget-metrics logout webapps window-mode window-switcher capture-ui; do
    install -Dm755 "$ROOT/scripts/forynarch-$helper.sh" "$root/usr/local/bin/forynarch-$helper"
done
for helper in window-control window-layout shortcut-config widget-packs terminal default-apps date-time notifications capture media emoji-font wallpaper audio audio-hardware bluetooth battery; do
  install -Dm755 "$ROOT/scripts/forynarch-$helper.py" "$root/usr/local/bin/forynarch-$helper"
done
install -Dm644 "$ROOT/scripts/forynarch_defaults.py" "$root/usr/local/bin/forynarch_defaults.py"
install -Dm644 "$ROOT/config/systemd/user/forynarch-wallpaper.service" "$root/usr/lib/systemd/user/forynarch-wallpaper.service"
install -Dm644 "$ROOT/config/systemd/user/thunar.service.d/10-forynarch.conf" "$root/usr/lib/systemd/user/thunar.service.d/10-forynarch.conf"
install -Dm755 "$ROOT/scripts/forynarch-vm.py" "$root/usr/local/bin/forynarch-vm"
install -Dm755 "$ROOT/scripts/forynarch-bluetooth-recover.sh" "$root/usr/local/libexec/forynarch-bluetooth-recover"
install -Dm644 "$ROOT/config/polkit-1/actions/org.forynarch.bluetooth.policy" "$root/usr/share/polkit-1/actions/org.forynarch.bluetooth.policy"
install -Dm755 "$ROOT/scripts/forynarch-vm-service.py" "$root/usr/local/libexec/forynarch-vm-service"
install -Dm644 "$ROOT/scripts/forynarch_vm.py" "$root/usr/local/lib/forynarch/forynarch_vm.py"
install -Dm644 "$ROOT/config/polkit-1/actions/org.forynarch.virtual-machine.policy" "$root/usr/share/polkit-1/actions/org.forynarch.virtual-machine.policy"
install -Dm644 "$ROOT/config/udev/rules.d/80-forynarch-vm.rules" "$root/usr/lib/udev/rules.d/80-forynarch-vm.rules"
install -Dm755 "$ROOT/scripts/forynarch-settings.sh" "$root/usr/local/bin/forynarch-settings"
install -Dm755 "$ROOT/scripts/forynarch-system.sh" "$root/usr/local/bin/forynarch-system"
install -Dm644 "$ROOT/scripts/system-settings-model.jq" "$root/usr/share/forynarch/system-settings-model.jq"
install -Dm644 "$ROOT/config/applications/forynarch-virtual-machines.desktop" "$root/usr/share/applications/forynarch-virtual-machines.desktop"
for app in screenshots clipboard;do
    install -Dm644 "$ROOT/config/applications/forynarch-$app.desktop" "$root/usr/share/applications/forynarch-$app.desktop"
done
bash "$ROOT/scripts/configure-terminal.sh" "$root"
bash "$ROOT/scripts/configure-browser.sh" "$root"
install -Dm644 "$ROOT/config/mako/config" "$root/etc/skel/.config/mako/config"
if [[ "$mode" == live ]]; then
    install -Dm644 "$ROOT/config/mako/config" "$root/home/liveuser/.config/mako/config"
fi
install -Dm644 "$ROOT/examples/widget-packs/workday.json" "$root/usr/share/forynarch/widget-packs/workday.json"
install -Dm644 "$ROOT/licenses/MacShell-MIT.txt" "$root/usr/share/licenses/forynarch/MacShell-MIT.txt"
documentation="$root/usr/share/doc/forynarch"
mkdir -p "$documentation/docs" "$documentation/examples/widget-packs"
cp -a "$ROOT/docs/." "$documentation/docs/"
install -m644 "$ROOT/README.md" "$documentation/README.md"
for notice in CREDITS.md CONTRIBUTING.md SECURITY.md; do
  install -m644 "$ROOT/$notice" "$documentation/$notice"
done
mkdir -p "$documentation/licenses"
cp -a "$ROOT/licenses/." "$documentation/licenses/"
install -m644 "$ROOT/examples/widget-packs/workday.json" "$documentation/examples/widget-packs/workday.json"
for file in config/sddm/themes/forynarch-kath/UPSTREAM.md config/sddm/themes/forynarch-kath/DESIGN.md config/hypr/identity.lua assets/branding/logo.svg assets/branding/logo-reference.png assets/icons/Forynarch/SOURCES.md licenses/Tabler-Icons.txt licenses/Unicode.txt config/zsh/SOURCES.md licenses/xero-dotfiles-CC0.txt licenses/zsh-autosuggestions-MIT.txt licenses/MacShell-MIT.txt config/quickshell/forynarch/MACSHELL-SOURCES.md; do
    install -Dm644 "$ROOT/$file" "$documentation/$file"
done
install -Dm644 "$ROOT/scripts/forynarch_app_identity.py" "$root/usr/local/bin/forynarch_app_identity.py"
install -Dm755 "$ROOT/scripts/forynarch-titlebars.py" "$root/usr/local/bin/forynarch-titlebars"
install -Dm644 "$ROOT/config/forynarch/titlebar-defaults.json" "$root/usr/share/forynarch/titlebar-defaults.json"
install -Dm644 "$ROOT/config/hypr/titlebar-defaults.lua" "$root/usr/share/forynarch/titlebar-defaults.lua"
install -Dm755 "$ROOT/scripts/forynarch-webapp-assets.py" "$root/usr/local/bin/forynarch-webapp-assets"
install -Dm644 "$ROOT/config/forynarch/shortcut-catalog.json" "$root/usr/share/forynarch/shortcut-catalog.json"
install -Dm644 "$ROOT/config/pacman/hooks/forynarch-desktop.hook" "$root/etc/pacman.d/hooks/forynarch-desktop.hook"
mkdir -p "$root/usr/share/forynarch" "$root/usr/share/applications" "$root/etc/systemd/system"
install -m644 "$ROOT/config/hypr/motion.lua" "$root/usr/share/forynarch/motion.lua"
install -Dm644 "$ROOT/config/hypr/windows.lua" "$root/etc/skel/.config/hypr/windows.lua"
for home in "$root/etc/skel" "$root/root" "$root/home/liveuser"; do
    [[ -d "$home/.config/hypr" ]] || continue
    if [[ -n "$titlebars" ]];then
      install -m644 "$ROOT/config/hypr/titlebars.lua" "$home/.config/hypr/titlebars.lua"
      if [[ -f "$home/.config/hypr/hyprland.lua" ]] && ! grep -Fq 'titlebars.lua' "$home/.config/hypr/hyprland.lua";then
        printf '\ndofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/titlebars.lua")\n' >> "$home/.config/hypr/hyprland.lua"
      fi
    fi
    install -m644 "$ROOT/config/hypr/identity.lua" "$home/.config/hypr/identity.lua"
    install -m644 "$ROOT/config/hypr/auto-snap.lua" "$home/.config/hypr/auto-snap.lua"
    if [[ -f "$home/.config/hypr/hyprland.lua" ]] && ! grep -Fq 'auto-snap.lua' "$home/.config/hypr/hyprland.lua"; then
        printf '\ndofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/auto-snap.lua")\n' >> "$home/.config/hypr/hyprland.lua"
    fi
    if [[ -f "$home/.config/hypr/hyprland.lua" ]] && ! grep -Fq 'identity.lua' "$home/.config/hypr/hyprland.lua"; then
        printf '\ndofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/identity.lua")\n' >> "$home/.config/hypr/hyprland.lua"
    fi
done
if [[ -d "$root/root/.config/hypr" ]];then install -m644 "$ROOT/config/hypr/windows.lua" "$root/root/.config/hypr/windows.lua";fi
install -m644 "$ROOT/config/cava/forynarch.conf" "$root/usr/share/forynarch/cava.conf"
install -m644 "$ROOT/assets/giphy/powered-by-giphy.png" "$root/usr/share/forynarch/powered-by-giphy.png"
install -Dm644 "$ROOT/licenses/Unicode.txt" "$root/usr/share/licenses/forynarch/Unicode.txt"
install -Dm644 "$ROOT/licenses/Tabler-Icons.txt" "$root/usr/share/licenses/forynarch/Tabler-Icons.txt"
install -Dm644 "$ROOT/licenses/xero-dotfiles-CC0.txt" "$root/usr/share/licenses/forynarch/xero-dotfiles-CC0.txt"
install -Dm644 "$ROOT/licenses/zsh-autosuggestions-MIT.txt" "$root/usr/share/licenses/forynarch/zsh-autosuggestions-MIT.txt"
mkdir -p "$root/usr/share/icons/Forynarch"
cp -a "$ROOT/assets/icons/Forynarch/." "$root/usr/share/icons/Forynarch/"
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -f -t "$root/usr/share/icons/Forynarch" >/dev/null
fi
install -Dm644 "$ROOT/config/fontconfig/60-forynarch-emoji.conf" "$root/etc/fonts/conf.d/60-forynarch-emoji.conf"
if [[ -d "$root/usr/share/icons/Forynarch/scalable/apps" ]]; then
    for name in org.xfce.thunar org.xfce.Thunar thunar Thunar; do
        ln -sfn system-file-manager.svg "$root/usr/share/icons/Forynarch/scalable/apps/$name.svg"
    done
fi
cp "$ROOT/packages/optional-catalog.yaml" "$root/usr/share/forynarch/optional-catalog.json"
for unit in avahi-daemon.service avahi-daemon.socket sshd.service sshd.socket systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service iwd.service; do
    ln -sfn /dev/null "$root/etc/systemd/system/$unit"
done
mkdir -p "$root/etc/systemd/system-generators"
ln -sfn /dev/null "$root/etc/systemd/system-generators/systemd-ssh-generator"
if [[ "$mode" == live ]]; then
    install -Dm755 "$ROOT/scripts/forynarch-install-system.py" "$root/usr/local/libexec/forynarch-install-system"
    install -Dm644 "$ROOT/scripts/install_layout.py" "$root/usr/share/forynarch/install_layout.py"
    install -Dm644 "$ROOT/config/polkit-1/actions/org.forynarch.install-system.policy" "$root/usr/share/polkit-1/actions/org.forynarch.install-system.policy"
printf '2\n' > "$root/usr/share/forynarch/installer-executor-version"
    install -Dm755 "$ROOT/scripts/forynarch-apps.sh" "$root/usr/local/bin/forynarch-apps"
    install -Dm755 "$ROOT/scripts/forynarch-install-app.sh" "$root/usr/local/libexec/forynarch-install-app"
    install -Dm644 "$ROOT/config/polkit-1/actions/org.forynarch.install-app.policy" "$root/usr/share/polkit-1/actions/org.forynarch.install-app.policy"
    install -Dm644 "$ROOT/config/live/49-forynarch-apps.rules" "$root/etc/polkit-1/rules.d/49-forynarch-apps.rules"
    for wants in multi-user.target.wants sockets.target.wants; do
        for unit in sshd.service sshd.socket avahi-daemon.service avahi-daemon.socket; do
            rm -f -- "$root/etc/systemd/system/$wants/$unit"
        done
    done
else
    install -Dm644 "$ROOT/config/systemd/logind.conf.d/20-forynarch-session.conf" "$root/etc/systemd/logind.conf.d/20-forynarch-session.conf"
    install -Dm644 "$ROOT/config/systemd/sddm.service.d/10-forynarch.conf" "$root/etc/systemd/system/sddm.service.d/10-forynarch.conf"
    [[ ! -e "$root/etc/polkit-1/rules.d/49-forynarch-apps.rules" ]] || { echo 'Live authorization leaked into target.' >&2;exit 1; }
fi
bash "$ROOT/scripts/forynarch-desktop-integrate.sh" "$root"
bash "$ROOT/scripts/configure-login.sh" "$root" "$mode"
