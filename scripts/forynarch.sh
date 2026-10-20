#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=scripts/arch-environment.sh
source "$ROOT/scripts/arch-environment.sh"

usage() {
  cat <<'HELP'
Forynarch automation (latest stable Arch; experimental until VM QA passes)
  bash scripts/forynarch.sh plan
  bash scripts/forynarch.sh doctor
  sudo bash scripts/forynarch.sh bootstrap --approve-host-packages
  sudo bash scripts/forynarch.sh build --approve-target-packages --approve-image-config
  sudo bash scripts/forynarch.sh build --approve-host-packages --approve-target-packages --approve-image-config
Optional: --allow-core-dependency python (requires dependency evidence)
Desktop: --desktop-shell glass|classic (default glass; builder qsb required)
Every approved build performs a full stable builder update before resolving
fresh target and Live packages. --approve-host-packages remains a bootstrap option.
No host disks are partitioned by this builder. There is no automatic cleanup.
The separate live installer defaults to review only and requires typed consent.
HELP
}

action="${1:-plan}"
[[ $# -eq 0 ]] || shift
approve_host=false approve_target=false approve_config=false
desktop_shell=glass
exceptions=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --approve-host-packages) approve_host=true ;;
    --approve-target-packages) approve_target=true ;;
    --approve-image-config) approve_config=true ;;
    --desktop-shell)
      [[ $# -ge 2 && ( "$2" == classic || "$2" == glass ) ]] || { echo 'Unknown desktop shell.' >&2; exit 2; }
      desktop_shell="$2"; shift ;;
    --allow-core-dependency)
      [[ $# -ge 2 && "$2" == python ]] || { echo 'Only the Python runtime exception is supported.' >&2; exit 2; }
      exceptions+=("$2"); shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
if [[ "$action" == plan ]]; then
  usage
  cat <<'PLAN'
Stages: approved builder update -> source tests -> stable package checks ->
independent core rootfs -> package-leak audit -> installed Hyprland example check
-> desktop integration -> target payload -> independent releng Live profile ->
ISO + checksums + package/version evidence -> separate disposable-VM QA.
Build success does not complete Calamares, hybrid/multi-monitor UX, dual boot,
drive aliases, Windows app integration or laptop power benchmarks.
PLAN
  exit 0
fi
case "$action" in doctor|bootstrap|build) ;; *) usage; exit 2 ;; esac
require_arch_environment
if [[ "$action" == doctor ]]; then
  bash "$ROOT/scripts/record-build-environment.sh"
  missing=0
  for command in mkarchiso pacstrap arch-chroot python luac shellcheck zstd rsvg-convert chafa; do
    if command -v "$command" >/dev/null; then printf 'OK: %s\n' "$command";
    else printf 'MISSING: %s\n' "$command"; missing=1; fi
  done
  exit "$missing"
fi
[[ "$(id -u)" == 0 ]] || { echo 'Run the approved operation as root in the Arch VM.' >&2; exit 1; }
if [[ "$action" == build && ( "$approve_target" != true || "$approve_config" != true ) ]];then
  echo 'Build requires target-package and image approval before its full builder update.' >&2;exit 2
fi
if [[ "$action" == bootstrap || "$action" == build || "$approve_host" == true ]]; then
  [[ "$action" == build || "$approve_host" == true ]] || { echo 'Host package approval is required.' >&2; exit 2; }
  echo 'Approved: full stable Arch builder update and installation of build/test tools.'
  host_repositories="$(pacman-conf --repo-list)"
  while IFS= read -r repository; do
    case "$repository" in core|extra|multilib) ;; *) echo "Builder repository is not stable official Arch: $repository" >&2; exit 1 ;; esac
  done <<< "$host_repositories"
  # Full update; no partial upgrade and no automatic Git/IDE installation.
  host_extras=()
  host_extras+=(qt6-shadertools gcc make pkgconf hyprland grub)
  pacman -Syu --needed --noconfirm archiso arch-install-scripts python lua shellcheck jq zstd librsvg chafa dosfstools e2fsprogs qemu-system-x86 edk2-ovmf "${host_extras[@]}"
  [[ "$action" != bootstrap ]] || exit 0
fi
[[ "$approve_target" == true && "$approve_config" == true ]] || {
  echo 'Build requires explicit target package and image configuration approval.' >&2; exit 2;
}
for command in mkarchiso pacstrap arch-chroot python luac shellcheck jq zstd rsvg-convert chafa; do
  command -v "$command" >/dev/null || { echo "Missing build tool: $command" >&2; exit 1; }
done
python -m unittest discover -s "$ROOT/tests" -p 'test_*.py'
python "$ROOT/scripts/hotkeys.py" --check
for script in "$ROOT"/scripts/*.sh; do bash -n "$script"; done
shellcheck -P "$ROOT" -x "$ROOT"/scripts/*.sh

require_local_destination "$ROOT/work"
require_local_destination "$ROOT/out"
mkdir -p "$ROOT/work" "$ROOT/out"
run="$(mktemp -d "$ROOT/work/pipeline-XXXXXXXX")"
result="$(mktemp -d "$ROOT/out/build-XXXXXXXX")"
target="$run/target"
profile="$run/profile"
bundle="$result/bundle"
mkdir -p "$target" "$bundle"
trap 'echo "Pipeline stopped. Generated evidence is retained; inspect work/ and out/." >&2' ERR
printf '%s\n' 'Build started; no installability claim until QA' > "$result/status.txt"
bash "$ROOT/scripts/record-build-environment.sh" > "$result/environment.txt"
bash "$ROOT/scripts/build-installer-shader.sh" "$run/installer-shaders"
bash "$ROOT/scripts/build-bluetooth-agent.sh" "$run/bluetooth-agent"
cp "$run/installer-shaders/shader-info.txt" "$result/installer-shader-info.txt"
cp "$run/installer-shaders/compiler-version.txt" "$result/installer-compiler-version.txt"
python "$ROOT/scripts/automation_support.py" packages "$ROOT/packages/target-core.proposed.txt" > "$run/core.txt"
mapfile -t core < "$run/core.txt"
if [[ "$desktop_shell" == glass ]]; then
  core+=(quickshell adwaita-fonts)
  printf 'quickshell\nadwaita-fonts\n' >> "$run/core.txt"
  bash "$ROOT/scripts/build-glass-shader.sh" "$run/glass-shaders"
fi
for forbidden in git nodejs npm python python-pip base-devel docker podman code rust rustup go; do
  if printf '%s\n' "${core[@]}" | grep -qx "$forbidden"; then
    echo "Explicit developer package forbidden in core: $forbidden" >&2; exit 1
  fi
done
# Use the installed upstream releng config (stable repos, signature checks).
upstream=/usr/share/archiso/configs/releng
[[ -f "$upstream/profiledef.sh" && -f "$upstream/pacman.conf" ]] || exit 1
cp "$upstream/pacman.conf" "$run/pacman.conf"
repositories="$(pacman-conf --config "$run/pacman.conf" --repo-list)"
while IFS= read -r repository; do
  case "$repository" in core|extra|multilib) ;; *) echo "Unapproved repository: $repository" >&2; exit 1 ;; esac
done <<< "$repositories"
for package in "${core[@]}"; do pacman -Si -- "$package" > /dev/null; done
[[ "$(pacman -Si quickshell | awk '/^Version/ {print $3}')" == 0.3.2-1 ]] || {
  echo 'Review the Quickshell release before building the standalone Live installer.' >&2; exit 1;
}
cp "$run/core.txt" "$result/core-explicit.requested.txt"
pacstrap -c -K -C "$run/pacman.conf" "$target" "${core[@]}"
if [[ "$desktop_shell" == glass ]]; then
  [[ "$(pacman --root "$target" -Q quickshell | awk '{print $2}')" == 0.3.2-1 ]] || {
    echo 'Review the installed Quickshell release before building the glass profile.' >&2; exit 1;
  }
fi
pacman --root "$target" -Q > "$bundle/core-packages.txt"
pacman --root "$target" -Qqe > "$bundle/core-explicit.txt"
for forbidden in git nodejs npm python python-pip base-devel docker podman code neovim rust rustup go archiso calamares; do
  if pacman --root "$target" -Q "$forbidden" >/dev/null 2>&1; then
    if [[ "$forbidden" == python && " ${exceptions[*]} " == *' python '* ]] &&
       ! grep -qx python "$bundle/core-explicit.txt"; then
      pacman --root "$target" -Qi python gpsd waybar > "$bundle/python-dependency-evidence.txt"
      python_required_by="$(pacman --root "$target" -Qi python | sed -n 's/^Required By[[:space:]]*:[[:space:]]*//p')"
      gpsd_required_by="$(pacman --root "$target" -Qi gpsd | sed -n 's/^Required By[[:space:]]*:[[:space:]]*//p')"
      python_required_by="$(printf '%s\n' "$python_required_by" | xargs -n1 | sort | xargs)"
      runtime_chain='official Waybar -> gpsd -> Python'
      if [[ "$python_required_by" == 'gpsd vapoursynth' ]]; then
        pacman --root "$target" -Qi vapoursynth ffmpeg qt6-multimedia-ffmpeg qt6-multimedia >> "$bundle/python-dependency-evidence.txt"
        vapoursynth_required_by="$(pacman --root "$target" -Qi vapoursynth | sed -n 's/^Required By[[:space:]]*:[[:space:]]*//p' | xargs)"
        ffmpeg_required_by="$(pacman --root "$target" -Qi ffmpeg | sed -n 's/^Required By[[:space:]]*:[[:space:]]*//p' | xargs)"
        [[ "$vapoursynth_required_by" == ffmpeg && "$ffmpeg_required_by" == qt6-multimedia-ffmpeg ]] || {
          echo 'Video runtime Python dependency chain changed; review package metadata.' >&2; exit 1;
        }
        runtime_chain+='; Kath video Qt Multimedia FFmpeg backend -> FFmpeg -> VapourSynth -> Python'
      elif [[ "$python_required_by" != gpsd ]]; then
        echo 'Python exception contains an unreviewed runtime consumer.' >&2; exit 1;
      fi
      [[ " $gpsd_required_by " == *' waybar '* ]] || {
        echo 'Python exception does not match the reviewed official Waybar -> gpsd -> Python chain.' >&2; exit 1;
      }
      printf 'Required runtime exception: %s. Developer Python group remains unselected.\n' "$runtime_chain" > "$bundle/core-runtime-exceptions.txt"
    else
      echo "Core leak/unapproved dependency: $forbidden. Review dependency chains." >&2; exit 1
    fi
  fi
done
version="$(pacman --root "$target" -Q hyprland | awk '{print $2}')"
example="$(pacman --root "$target" -Ql hyprland | awk '$2 ~ /\/hyprland\.lua$/ {print $2; exit}')"
example="${example#"$target"}"
[[ -n "$example" && -f "$target$example" ]] || { echo 'Packaged Lua example missing.' >&2; exit 1; }
mkdir -p "$target/etc/skel/.config/hypr" "$target/usr/local/bin"
python "$ROOT/scripts/automation_support.py" adapt "$target$example" "$version" "$target/etc/skel/.config/hypr/hyprland.lua" > "$result/hyprland-adaptation.txt"
luac -p "$target/etc/skel/.config/hypr/hyprland.lua"
cp -a "$ROOT/config/alacritty" "$ROOT/config/fuzzel" "$ROOT/config/mako" "$ROOT/config/waybar" \
  "$ROOT/config/gtk-3.0" "$ROOT/config/gtk-4.0" "$ROOT/config/Thunar" "$ROOT/config/xfce4" "$target/etc/skel/.config/"
install -m644 "$ROOT/config/hypr/hyprlock.conf" "$target/etc/skel/.config/hypr/hyprlock.conf"
install -m644 "$ROOT/config/hypr/bindings.lua" "$target/etc/skel/.config/hypr/bindings.lua"
mkdir -p "$target/etc/skel/.config/systemd/user"
install -m644 "$ROOT/config/systemd/user/forynarch-idle.service" "$target/etc/skel/.config/systemd/user/forynarch-idle.service"
install -m755 "$ROOT/scripts/forynarch-session-start.sh" "$target/usr/local/bin/forynarch-session-start"
install -m755 "$run/bluetooth-agent/forynarch-bluetooth-pair" "$target/usr/local/bin/forynarch-bluetooth-pair"
for helper in menu power shortcuts workspace launcher drives files application-theme settings system display window-switcher hotkey storage setup partitions live-diagnostics; do
  install -m755 "$ROOT/scripts/forynarch-$helper.sh" "$target/usr/local/bin/forynarch-$helper"
done
install -Dm644 "$ROOT/assets/wallpapers/navy.svg" "$target/usr/share/backgrounds/forynarch/navy.svg"
mkdir -p "$target/usr/share/icons" "$target/etc/udisks2"
cp -a "$ROOT/assets/icons/Forynarch" "$target/usr/share/icons/"
install -Dm644 "$ROOT/config/applications/forynarch-drives.desktop" "$target/usr/share/applications/forynarch-drives.desktop"
install -Dm644 "$ROOT/config/applications/forynarch-settings.desktop" "$target/usr/share/applications/forynarch-settings.desktop"
install -Dm644 "$ROOT/scripts/storage-model.jq" "$target/usr/share/forynarch/storage-model.jq"
install -m644 "$ROOT/config/forynarch/partition-manager.qss" "$target/usr/share/forynarch/partition-manager.qss"
install -m644 "$ROOT/scripts/system-settings-model.jq" "$target/usr/share/forynarch/system-settings-model.jq"
install -m644 "$ROOT/config/forynarch/hotkeys.txt" "$target/usr/share/forynarch/hotkeys.txt"
for model in storage-inventory storage-plan; do install -m644 "$ROOT/scripts/$model.jq" "$target/usr/share/forynarch/$model.jq"; done
install -m644 "$ROOT/packages/optional-catalog.yaml" "$target/usr/share/forynarch/optional-catalog.json"
install -m644 "$ROOT/config/udisks2/mount_options.conf" "$target/etc/udisks2/mount_options.conf"
install -m644 "$ROOT/config/glib-2.0/90_forynarch.gschema.override" "$target/usr/share/glib-2.0/schemas/90_forynarch.gschema.override"
arch-chroot "$target" glib-compile-schemas --strict /usr/share/glib-2.0/schemas
if [[ "$desktop_shell" == glass ]]; then
  mkdir -p "$target/etc/skel/.config/quickshell" "$target/etc/skel/.config/forynarch"
  cp -a "$ROOT/config/quickshell/forynarch" "$target/etc/skel/.config/quickshell/"
  for shader in glass motion liquid;do
    install -m644 "$run/glass-shaders/$shader.frag.qsb" "$target/etc/skel/.config/quickshell/forynarch/shaders/$shader.frag.qsb"
  done
  install -m755 "$ROOT/scripts/forynarch-glass-start.sh" "$target/usr/local/bin/forynarch-glass-start"
  printf 'glass\n' > "$target/etc/skel/.config/forynarch/desktop-shell"
  cp "$run/glass-shaders/shader-info.txt" "$result/glass-shader-info.txt"
  cp "$run/glass-shaders/compiler-version.txt" "$result/glass-compiler-version.txt"
fi
cat > "$target/etc/skel/.bash_profile" <<'LOGIN'
[[ ! -f ~/.bashrc ]] || source ~/.bashrc
LOGIN
systemctl --root "$target" enable NetworkManager.service
systemctl --root "$target" enable bluetooth.service
pacman --root "$target" -Q sddm > "$result/sddm-version.txt"
grep -Eq '^sddm 0\.21\.0-' "$result/sddm-version.txt" || { echo 'Review the installed SDDM release and login theme before building.' >&2; exit 1; }
install -Dm644 "$ROOT/config/sddm/10-forynarch.conf" "$target/etc/sddm.conf.d/10-forynarch.conf"
mkdir -p "$target/usr/share/sddm/themes"
systemctl --root "$target" enable sddm.service
bash "$ROOT/scripts/build-window-controls.sh" "$run/window-controls"
export FORYNARCH_WINDOW_CONTROLS_DIR="$run/window-controls"
bash "$ROOT/scripts/build-titlebars.sh" "$run/titlebars"
export FORYNARCH_TITLEBARS_DIR="$run/titlebars"
FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION="$(pacman --root "$target" -Q hyprland)"
export FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION
bash "$ROOT/scripts/integrate-desktop.sh" "$target" target
printf 'KEYMAP=us\n' > "$target/etc/vconsole.conf"
# A directory payload has no final root-device mapping. Make its initial image
# portable; restore packaged autodetection when installing onto a mounted disk.
mkdir -p "$target/usr/share/forynarch"
install -m644 "$target/etc/mkinitcpio.conf" "$target/usr/share/forynarch/mkinitcpio.conf.install"
bash "$ROOT/scripts/configure-boot.sh" "$target"
sed -i '/^HOOKS=/s/[[:space:]]autodetect[[:space:]]/ /' "$target/etc/mkinitcpio.conf"
arch-chroot "$target" mkinitcpio -P
printf '' > "$target/etc/machine-id"
ln -sfn /run/NetworkManager/resolv.conf "$target/etc/resolv.conf"
# Independent payload; no live installer/runtime copied into target.
tar --zstd --acls --xattrs --numeric-owner -cpf "$bundle/target-rootfs.tar.zst" \
  --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' --exclude='./run/*' \
  --exclude='./tmp/*' --exclude='./var/cache/pacman/pkg/*' \
  --exclude='./etc/ssh/ssh_host_*' --exclude='./var/lib/systemd/random-seed' \
  --exclude='./etc/pacman.d/gnupg/*' -C "$target" .
tar --zstd -cpf "$bundle/package-db.tar.zst" -C "$target/var/lib/pacman" local sync
python "$ROOT/scripts/automation_support.py" archive "$bundle/target-rootfs.tar.zst"
python "$ROOT/scripts/automation_support.py" archive "$bundle/package-db.tar.zst"
cp "$ROOT/packages/optional-catalog.yaml" "$bundle/optional-catalog.yaml"
cp "$ROOT/scripts/package_plan.py" "$ROOT/scripts/automation_support.py" "$ROOT/scripts/install_layout.py" "$bundle/"
cp "$ROOT/packages/driver-catalog.json" "$bundle/driver-catalog.json"
cp "$ROOT/scripts/local_applications.py" "$bundle/"
python "$ROOT/scripts/bundle-local-applications.py" "$ROOT" "$bundle"
cp "$run/pacman.conf" "$bundle/pacman.conf"
(cd "$bundle" && sha256sum target-rootfs.tar.zst package-db.tar.zst core-packages.txt core-explicit.txt optional-catalog.yaml package_plan.py automation_support.py install_layout.py driver-catalog.json pacman.conf > SHA256SUMS)
(cd "$bundle" && sha256sum local_applications.py local-applications.json >> SHA256SUMS; find optional -maxdepth 1 -type f -name '*.pkg.tar.zst' -exec sha256sum {} + >> SHA256SUMS)
if [[ -f "$bundle/core-runtime-exceptions.txt" ]]; then
  (cd "$bundle" && sha256sum core-runtime-exceptions.txt python-dependency-evidence.txt >> SHA256SUMS)
fi

cp -a "$upstream" "$profile"
python "$ROOT/scripts/live_boot_policy.py" "$profile" > "$result/live-boot-policy.txt"
cat >> "$profile/profiledef.sh" <<'BRAND'
iso_name="forynarch"
iso_label="FORYN_$(date +%Y%m)"
iso_publisher="Forynarch / Muhammad Muzammil Fadhil"
iso_application="Forynarch experimental live and dedicated-disk CLI installer"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3' '-b' '1M')
BRAND
live="$profile/airootfs"
# The installed target and new Live profiles use the same connection manager.
# These are staging-root links only; never alter host or running VM networking.
mkdir -p "$live/etc/systemd/system/multi-user.target.wants" "$live/etc/systemd/system/bluetooth.target.wants"
ln -sfn /usr/lib/systemd/system/NetworkManager.service "$live/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sfn /usr/lib/systemd/system/bluetooth.service "$live/etc/systemd/system/bluetooth.target.wants/bluetooth.service"
for legacy in systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service; do
  for wants in multi-user.target.wants sockets.target.wants network-online.target.wants; do
    rm -f -- "$live/etc/systemd/system/$wants/$legacy"
  done
done
mkdir -p "$live/usr/share/forynarch" "$live/usr/local/bin" "$live/root/.config" "$live/etc/skel"
cp -a "$bundle/." "$live/usr/share/forynarch/"
install -m755 "$ROOT/scripts/install-target.sh" "$live/usr/local/bin/forynarch-install"
install -m755 "$ROOT/scripts/forynarch-session-start.sh" "$live/usr/local/bin/forynarch-session-start"
install -m755 "$run/bluetooth-agent/forynarch-bluetooth-pair" "$live/usr/local/bin/forynarch-bluetooth-pair"
cp -a "$target/etc/skel/.config/." "$live/root/.config/"
cp -a "$target/etc/skel/." "$live/etc/skel/"
if [[ "$desktop_shell" == glass ]]; then
  install -m755 "$ROOT/scripts/forynarch-glass-start.sh" "$live/usr/local/bin/forynarch-glass-start"
  printf '\nfile_permissions+=( ["/usr/local/bin/forynarch-glass-start"]="0:0:755" )\n' >> "$profile/profiledef.sh"
fi
for helper in menu power shortcuts workspace launcher drives files application-theme settings system display window-switcher hotkey storage setup partitions live-diagnostics; do
  install -m755 "$ROOT/scripts/forynarch-$helper.sh" "$live/usr/local/bin/forynarch-$helper"
done
install -Dm644 "$ROOT/assets/wallpapers/navy.svg" "$live/usr/share/backgrounds/forynarch/navy.svg"
mkdir -p "$live/usr/share/icons" "$live/etc/udisks2"
cp -a "$ROOT/assets/icons/Forynarch" "$live/usr/share/icons/"
install -Dm644 "$ROOT/config/applications/forynarch-drives.desktop" "$live/usr/share/applications/forynarch-drives.desktop"
install -Dm644 "$ROOT/config/applications/forynarch-settings.desktop" "$live/usr/share/applications/forynarch-settings.desktop"
install -m644 "$ROOT/scripts/storage-model.jq" "$live/usr/share/forynarch/storage-model.jq"
install -m644 "$ROOT/config/forynarch/partition-manager.qss" "$live/usr/share/forynarch/partition-manager.qss"
install -m644 "$ROOT/scripts/system-settings-model.jq" "$live/usr/share/forynarch/system-settings-model.jq"
install -m644 "$ROOT/config/forynarch/hotkeys.txt" "$live/usr/share/forynarch/hotkeys.txt"
for model in storage-inventory storage-plan; do install -m644 "$ROOT/scripts/$model.jq" "$live/usr/share/forynarch/$model.jq"; done
install -m644 "$ROOT/packages/optional-catalog.yaml" "$live/usr/share/forynarch/optional-catalog.json"
install -m644 "$ROOT/config/applications/forynarch-install.desktop" "$live/usr/share/applications/forynarch-install.desktop"
install -m755 "$ROOT/scripts/forynarch-installer-info.sh" "$live/usr/local/bin/forynarch-installer-info"
install -m755 "$ROOT/scripts/forynarch-installer-review.sh" "$live/usr/local/bin/forynarch-installer-review"
install -m644 "$ROOT/scripts/installer-review.jq" "$live/usr/share/forynarch/installer-review.jq"
install -m644 "$ROOT/packages/driver-catalog.json" "$live/usr/share/forynarch/driver-catalog.json"
for home_config in "$live/etc/skel/.config" "$live/root/.config"; do
mkdir -p "$home_config/quickshell"
cp -a "$ROOT/config/quickshell/forynarch-installer" "$home_config/quickshell/"
install -m644 "$run/installer-shaders/welcome.frag.qsb" "$home_config/quickshell/forynarch-installer/shaders/welcome.frag.qsb"
done
install -m644 "$ROOT/config/udisks2/mount_options.conf" "$live/etc/udisks2/mount_options.conf"
install -Dm644 "$ROOT/config/glib-2.0/90_forynarch.gschema.override" "$live/usr/share/glib-2.0/schemas/90_forynarch.gschema.override"
# Live boot preparation compiles the override before opening the desktop.
install -m755 "$ROOT/scripts/forynarch-live-prepare.sh" "$live/usr/local/bin/forynarch-live-prepare"
install -Dm644 "$ROOT/config/live/forynarch-live-prepare.service" "$live/etc/systemd/system/forynarch-live-prepare.service"
cat >> "$profile/profiledef.sh" <<'PERMISSIONS'
file_permissions+=(
  ["/usr/local/bin/forynarch-install"]="0:0:755"
  ["/usr/local/bin/forynarch-session-start"]="0:0:755"
  ["/usr/local/bin/forynarch-menu"]="0:0:755"
  ["/usr/local/bin/forynarch-power"]="0:0:755"
  ["/usr/local/bin/forynarch-shortcuts"]="0:0:755"
  ["/usr/local/bin/forynarch-live-prepare"]="0:0:755"
  ["/usr/local/bin/forynarch-workspace"]="0:0:755"
  ["/usr/local/bin/forynarch-launcher"]="0:0:755"
  ["/usr/local/bin/forynarch-drives"]="0:0:755"
  ["/usr/local/bin/forynarch-files"]="0:0:755"
  ["/usr/local/bin/forynarch-application-theme"]="0:0:755"
  ["/usr/local/bin/forynarch-settings"]="0:0:755"
  ["/usr/local/bin/forynarch-system"]="0:0:755"
  ["/usr/local/bin/forynarch-battery"]="0:0:755"
  ["/usr/local/bin/forynarch-bluetooth-pair"]="0:0:755"
  ["/usr/local/bin/forynarch-live-diagnostics"]="0:0:755"
  ["/usr/local/bin/forynarch-display"]="0:0:755"
  ["/usr/local/bin/forynarch-window-switcher"]="0:0:755"
  ["/usr/local/bin/forynarch-hotkey"]="0:0:755"
  ["/usr/local/bin/forynarch-storage"]="0:0:755"
  ["/usr/local/bin/forynarch-partitions"]="0:0:755"
  ["/usr/local/bin/forynarch-setup"]="0:0:755"
  ["/usr/local/bin/forynarch-installer-info"]="0:0:755"
  ["/usr/local/bin/forynarch-installer-review"]="0:0:755"
)
PERMISSIONS
# Live-only installer Python is deliberate. It is never a target manifest.
printf 'LANG=C.UTF-8\n' > "$live/etc/locale.conf"
manifest="$profile/packages.x86_64"
[[ -f "$manifest" ]] || { echo 'Review changed installed archiso profile manifest.' >&2; exit 1; }
sed -i '/^grml-zsh-config$/d' "$manifest"
sed -i -E '/^(openssh|tigervnc|x11vnc|avahi)$/d' "$manifest"
bash "$ROOT/scripts/integrate-desktop.sh" "$live" live
python "$ROOT/scripts/archiso_executable_policy.py" "$profile"
for package in "${core[@]}"; do
  printf '%s\n' "$package" >> "$manifest"
done
printf '%s\n' python arch-install-scripts dosfstools e2fsprogs zstd quickshell firefox >> "$manifest"
sort -u "$manifest" -o "$manifest"
printf '%s\n' 'Forynarch Live: use the graphical Welcome to try or install. Ctrl+Alt+F2 opens a recovery console.' \
  'CLI install: forynarch-install --help. UEFI installation on a dedicated disk or prepared root and EFI partitions.' > "$live/etc/motd"
cp "$manifest" "$result/live-packages.requested.txt"
bash "$ROOT/scripts/configure-boot.sh" "$live"
python "$ROOT/scripts/boot_policy.py" profile "$profile"
python "$ROOT/scripts/grub_theme.py" profile "$profile"
(cd "$profile" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$result/profile.sha256"
mkarchiso -v -w "$run/archiso-work" -o "$result" "$profile"
live_version="$(pacman --root "$run/archiso-work/x86_64/airootfs" -Q hyprland)"
[[ "$live_version" == "$FORYNARCH_WINDOW_CONTROLS_HYPRLAND_VERSION" && "$live_version" == "$(cat "$run/titlebars/hyprland-version.txt")" ]] || {
  echo 'The completed Live root does not match the compiled Hyprland extensions.' >&2;exit 1;
}
printf '%s\n' "$live_version" > "$result/live-hyprland-version.txt"
(cd "$result" && find . -maxdepth 1 -type f -name '*.iso' -print0 | sort -z | xargs -0 -r sha256sum) > "$result/iso.sha256"
[[ -s "$result/iso.sha256" ]] || { echo 'No ISO produced.' >&2; exit 1; }
cat > "$result/status.txt" <<'STATUS'
Artifacts built; NOT a validated release.
Pending: UEFI VM boot, zero/selective/offline installer matrix, cancellation,
real GPU desktop, Calamares, hybrid monitor UX, storage and power hardware QA.
STATUS
printf 'Pipeline artifacts: %s\n' "$result"
