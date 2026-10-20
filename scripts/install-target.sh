#!/usr/bin/env bash
# Live installer. No writes without --execute and disk-specific consent.
set -euo pipefail
set +x
export LC_ALL=C
bundle=/usr/share/forynarch
disk_id='' username=forynarch hostname=forynarch timezone=UTC
execute=false offline=false loop_test=false no_password=false gui=false
full_name='' keyboard=us gui_password=''
selected=()
selected_drivers=()
root_partition_id='' efi_partition_id='' manual=false register_boot_entry=false efi_mount=efi
usage() {
  cat <<'HELP'
Forynarch CLI installer (UEFI, ext4)
  forynarch-install --disk /dev/disk/by-id/DEVICE [--select git] [--offline]
  forynarch-install --disk /dev/disk/by-id/DEVICE --username NAME --timezone Asia/Jakarta --execute
Optional: --hostname NAME; repeated --select GROUP_ID; --bundle DIRECTORY
Optional: repeated --driver intel-vulkan or --driver amd-vulkan (matching GPU only)
Optional: --no-password creates an account with an empty password; local sign-in
will not ask for a password. This does not enable automatic login.
Review is the default. --execute still requires typed disk-specific confirmation.
Execution erases the entire selected disk, installs core + chosen groups, creates
an administrator, sets a password interactively and installs EFI fallback files.
Prepared partitions: --root-partition /dev/disk/by-partuuid/UUID
  --efi-partition /dev/disk/by-partuuid/UUID [--register-boot-entry]
This formats only the selected Linux root partition and preserves the FAT32 ESP
and other partitions. Prepare space with KDE Partition Manager before installing.
No automatic resizing, encryption, Secure Boot or BIOS installation support.
Disposable loop-device QA only: --disk /dev/loopN --allow-loop-test
No automatic reboot, password arguments, noninteractive erase or default extras.
HELP
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --execute) execute=true ;;
    --offline) offline=true ;;
    --no-password) no_password=true ;;
    --gui) gui=true ;;
    --allow-loop-test) loop_test=true ;;
    --register-boot-entry) register_boot_entry=true ;;
    --disk|--username|--hostname|--timezone|--bundle|--select|--driver|--full-name|--keyboard|--root-partition|--efi-partition)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      case "$1" in
        --disk) disk_id="$2" ;; --username) username="$2" ;;
        --hostname) hostname="$2" ;; --timezone) timezone="$2" ;;
        --full-name) full_name="$2" ;; --keyboard) keyboard="$2" ;;
        --bundle) bundle="$2" ;; --select) selected+=("--select" "$2") ;;
        --driver) selected_drivers+=("$2") ;;
        --root-partition) root_partition_id="$2" ;; --efi-partition) efi_partition_id="$2" ;;
      esac
      shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
if [[ -n "$root_partition_id" || -n "$efi_partition_id" ]];then
  [[ -n "$root_partition_id" && -n "$efi_partition_id" ]] || { echo 'Choose both root and EFI partitions.' >&2;exit 2; }
  manual=true;efi_mount=efi
elif [[ "$register_boot_entry" == true ]];then
  echo 'Firmware registration is available only with prepared partitions.' >&2;exit 2
fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Use the Arch-based live VM.' >&2; exit 1; }
[[ -n "$disk_id" ]] || { usage; exit 2; }
[[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$username" != root ]] || { echo 'Invalid user name.' >&2; exit 2; }
[[ "$hostname" =~ ^[a-z0-9][a-z0-9-]{0,62}$ && "$hostname" != *- ]] || { echo 'Invalid hostname.' >&2; exit 2; }
[[ "$timezone" == UTC || "$timezone" =~ ^[A-Za-z_]+(/[A-Za-z0-9_+-]+)+$ ]] || { echo 'Invalid timezone.' >&2; exit 2; }
[[ -f "/usr/share/zoneinfo/$timezone" ]] || { echo 'Unknown timezone.' >&2; exit 2; }
if [[ "$disk_id" =~ ^/dev/disk/by-id/[A-Za-z0-9][A-Za-z0-9_.:+-]*$ ]]; then
  [[ -L "$disk_id" ]] || { echo 'Stable disk ID must be an existing udev symlink.' >&2; exit 2; }
else
  [[ "$loop_test" == true && "$disk_id" =~ ^/dev/loop[0-9]+$ ]] || {
    echo 'Use a stable whole-disk /dev/disk/by-id path.' >&2; exit 2;
  }
fi
disk="$(readlink -f "$disk_id")"
[[ -b "$disk" ]] || { echo 'Target is not a block device.' >&2; exit 1; }
disk_type="$(lsblk -dn -o TYPE "$disk")"
[[ "$disk_type" == disk || ( "$loop_test" == true && "$disk_type" == loop ) ]] || { echo 'Whole disk required.' >&2; exit 1; }
[[ "$(lsblk -dn -o RO "$disk")" == 0 ]] || { echo 'Read-only target.' >&2; exit 1; }
for command in python zstd tar sha256sum pacman pacman-key sfdisk mkfs.vfat mkfs.ext4 arch-chroot genfstab udevadm; do
  command -v "$command" >/dev/null || { echo "Missing installer tool: $command" >&2; exit 1; }
done
unused_disk() {
  local member major swap majors members mounted swaps
  majors="$(lsblk -nr -o MAJ:MIN "$disk")"
  members="$(lsblk -nrpo NAME "$disk")"
  mounted="$(findmnt -rn -o MAJ:MIN)"
  swaps="$(swapon --show --noheadings --raw --output NAME)"
  [[ -n "$majors" && -n "$members" && -n "$mounted" ]] || { echo 'Device/mount enumeration failed.' >&2; return 1; }
  while IFS= read -r major; do
    if grep -Fqx "$major" <<< "$mounted"; then
      echo 'Refusing a disk with mounted filesystems, including live/system media.' >&2; return 1
    fi
  done <<< "$majors"
  while IFS= read -r member; do
    if [[ -d "/sys/class/block/${member##*/}/holders" &&
          -n "$(find "/sys/class/block/${member##*/}/holders" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      echo 'Refusing a disk with active device-mapper/RAID holders.' >&2; return 1
    fi
  done <<< "$members"
  while IFS= read -r swap; do
    [[ -b "$swap" ]] || continue
    major="$(lsblk -dn -o MAJ:MIN "$swap")"
    if grep -Fqx "$major" <<< "$majors"; then
      echo 'Refusing a disk with active swap.' >&2; return 1
    fi
  done <<< "$swaps"
}
unused_disk
bytes="$(blockdev --getsize64 "$disk")"
[[ "$bytes" -ge 34359738368 ]] || { echo 'A dedicated disk of at least 32 GiB is required.' >&2; exit 1; }
fingerprint() { lsblk -dnbo MAJ:MIN,SIZE,MODEL,SERIAL "$disk" | sha256sum | awk '{print $1}'; }
identity="$(fingerprint)"
bundle="$(realpath "$bundle")"
[[ -f "$bundle/SHA256SUMS" ]] || { echo 'Missing verified core bundle.' >&2; exit 1; }
(cd "$bundle" && sha256sum --quiet -c SHA256SUMS)
python "$bundle/automation_support.py" archive "$bundle/package-db.tar.zst"
python "$bundle/automation_support.py" archive "$bundle/target-rootfs.tar.zst"
state="$(mktemp -d /tmp/forynarch-install-XXXXXXXX)"
mountroot=''
cleanup() {
  local status=$?
  if [[ -n "$mountroot" ]]; then
    if mountpoint -q "$mountroot/$efi_mount"; then umount "$mountroot/$efi_mount" || echo 'EFI mount remains; inspect before reboot.' >&2; fi
    if mountpoint -q "$mountroot"; then umount "$mountroot" || echo 'Root mount remains; inspect before reboot.' >&2; fi
  fi
  if mountpoint -q "$state/efi-check";then umount "$state/efi-check" || true;fi
  if [[ "$status" != 0 ]]; then echo 'Installation stopped. Inspect the selected disk and installation log before retrying.' >&2; fi
  # Temporary evidence retained; no recursive cleanup and no password logging.
}
trap cleanup EXIT
manual_identity=''
if [[ "$manual" == true ]];then
  forynarch-storage list | python "$bundle/install_layout.py" inspect "$disk" "$root_partition_id" "$efi_partition_id" "$register_boot_entry" > "$state/manual-layout.json"
  if ! sfdisk --verify "$disk" > "$state/partition-table-check.txt" 2>&1;then
    echo 'The partition table failed its integrity check. Open Partition Manager to inspect it; no disk changes were made.' >&2
    cat "$state/partition-table-check.txt" >&2;exit 1
  fi
  manual_identity="$(sfdisk --json "$disk" | sha256sum | cut -d' ' -f1)"
  if [[ "$register_boot_entry" == true ]];then command -v efibootmgr >/dev/null || { echo 'Firmware boot-entry support is unavailable.' >&2;exit 1; };fi
fi
mkdir "$state/db" "$state/cache"
tar --zstd -xpf "$bundle/package-db.tar.zst" -C "$state/db"
plan_args=()
[[ "$offline" != true ]] || plan_args+=(--offline)
python "$bundle/package_plan.py" --catalog "$bundle/optional-catalog.yaml" "${selected[@]}" "${plan_args[@]}" > "$state/selection.json"
optional_text="$(python "$bundle/local_applications.py" repo "$bundle" "$state/selection.json")"
mapfile -t flatpak_apps < <(python -c 'import json,sys; sys.stdout.write("\n".join(json.load(open(sys.argv[1])).get("selected_flatpaks",[])))' "$state/selection.json")
optional=()
[[ -z "$optional_text" ]] || mapfile -t optional <<< "$optional_text"
driver_text="$(forynarch-installer-info | python "$bundle/install_layout.py" drivers "$bundle/driver-catalog.json" "$offline" "${selected_drivers[@]}")"
drivers=()
[[ -z "$driver_text" ]] || mapfile -t drivers <<< "$driver_text"
optional+=("${drivers[@]}")
local_names_text="$(python "$bundle/local_applications.py" names "$bundle" "$state/selection.json")"
local_files_text="$(python "$bundle/local_applications.py" files "$bundle" "$state/selection.json")"
local_names=();local_files=()
[[ -z "$local_names_text" ]] || mapfile -t local_names <<< "$local_names_text"
[[ -z "$local_files_text" ]] || mapfile -t local_files <<< "$local_files_text"
python "$bundle/local_applications.py" inventory "$bundle" "$state/selection.json" > "$state/local-transaction.txt"
if [[ ${#optional[@]} -gt 0 ]]; then
  pacman --config "$bundle/pacman.conf" --dbpath "$state/db" --cachedir "$state/cache" \
    -Sp --needed --print-format '%n %v %s' -- "${optional[@]}" > "$state/optional-transaction.txt"
  pacman --config "$bundle/pacman.conf" --dbpath "$state/db" --cachedir "$state/cache" \
    -Sp --needed --print-format '%n %v %h' -- "${optional[@]}" > "$state/package-identities.txt"
  pacman --config "$bundle/pacman.conf" --dbpath "$state/db" --cachedir "$state/cache" \
    -Sp --needed --print-format '%f %g' -- "${optional[@]}" > "$state/package-signatures.txt"
else
  printf '' > "$state/optional-transaction.txt"
fi
if [[ "$manual" == true ]];then
  jq -r .summary "$state/manual-layout.json"
  printf 'EFI partition is preserved at /efi. Create Forynarch firmware entry: %s\n' "$register_boot_entry"
else printf '\nREVIEW: ALL PARTITIONS AND DATA ON %s WILL BE ERASED.\n' "$disk_id";fi
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
if [[ "$manual" != true ]];then printf 'New layout: GPT; 2 GiB EFI/FAT32; remaining space ext4 root.\n';fi
printf 'Account: %s (wheel administrator); hostname: %s; timezone: %s\n' "$username" "$hostname" "$timezone"
printf 'Core packages from verified payload:\n'
cat "$bundle/core-packages.txt"
if [[ -f "$bundle/core-runtime-exceptions.txt" ]]; then
  printf 'Mandatory OS runtime dependency disclosure:\n'
  cat "$bundle/core-runtime-exceptions.txt"
fi
printf 'Explicit optional choices:\n'
cat "$state/selection.json"
printf 'Planned optional transaction: name version download-bytes (initial cache state)\n'
cat "$state/optional-transaction.txt"
cat "$state/local-transaction.txt"
printf 'Actions include extraction, user/password/sudo setup, initramfs, NetworkManager and GRUB EFI startup files with the Particle Circle theme.\n'
if [[ "$register_boot_entry" != true ]];then printf 'Firmware NVRAM entries will not be changed.\n';fi
printf 'No reboot is performed.\n'
printf 'Account: %s (%s); keyboard: %s; passwordless sign-in: %s\n' "$username" "$full_name" "$keyboard" "$no_password"
if [[ "$execute" != true ]]; then echo 'Review only: no disk, account, EFI or package changes performed.'; exit 0; fi
[[ "$(id -u)" == 0 && ( "$gui" == true || ( -t 0 && -t 1 ) ) ]] || { echo 'Execution requires root and an interactive terminal or the graphical consent transport.' >&2; exit 1; }
[[ -d /sys/firmware/efi || "$loop_test" == true ]] || { echo 'UEFI boot is required.' >&2; exit 1; }
secureboot=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
if [[ -f "$secureboot" && "$(od -An -t u1 -j4 -N1 "$secureboot" | tr -d ' ')" == 1 ]]; then
  echo 'Secure Boot support is not implemented.' >&2; exit 1
fi
expected_consent="ERASE ALL DATA ON $disk_id"
if [[ "$manual" == true ]];then expected_consent="INSTALL ON $root_partition_id";fi
printf 'To approve the reviewed operations, type exactly: %s\n> ' "$expected_consent"
IFS= read -r consent
[[ "$consent" == "$expected_consent" ]] || { echo 'Cancelled. Disk unchanged.'; exit 1; }
if [[ "$gui" == true && "$no_password" != true ]]; then
    IFS= read -r gui_password || { echo 'Password input ended. Disk unchanged.' >&2;exit 1; }
    [[ ${#gui_password} -ge 8 ]] || { echo 'Password is too short. Disk unchanged.' >&2;exit 1; }
fi
case "$keyboard" in us|gb|de|fr|es|br|jp|id) ;; *) echo 'Unsupported keyboard layout.' >&2;exit 2;;esac
[[ ${#full_name} -le 100 && "$full_name" != *$'\n'* && "$full_name" != *:* ]] || { echo 'Invalid full name.' >&2;exit 2; }
progress() { printf '\nFORYNARCH_STAGE %s\n' "$1"; }
progress download
if (( ${#flatpak_apps[@]} )); then
  for command in systemd-nspawn setpriv unshare; do
    command -v "$command" >/dev/null || { echo "Missing Flatpak installer tool: $command. No disk changes were made." >&2;exit 1; }
  done
  if ! setpriv --no-new-privs --reuid=65534 --regid=65534 --clear-groups unshare --user --map-root-user true; then
    echo 'Selected Flatpak apps require working user namespaces in the Live session. Restart with the standard Forynarch kernel or deselect these apps. No disk changes were made.' >&2
    exit 1
  fi
fi
# Download/resolve against the bundled snapshot before any partition write.
if [[ ${#optional[@]} -gt 0 ]]; then
  pacman --config "$bundle/pacman.conf" --dbpath "$state/db" --cachedir "$state/cache" \
    -Sw --needed --noconfirm -- "${optional[@]}"
  # Verify the signed package payloads before any disk operation. Signatures
  # may be embedded in the snapshot metadata instead of detached downloads.
  while read -r filename signature; do
    [[ "$filename" =~ ^[A-Za-z0-9][A-Za-z0-9@._+:-]*\.pkg\.tar\.(zst|xz)$ && -n "$signature" ]] || {
      echo 'Missing/invalid signed package metadata.' >&2; exit 1;
    }
    [[ -f "$state/cache/$filename" ]] || { echo 'Downloaded package missing.' >&2; exit 1; }
    printf '%s' "$signature" | base64 -d > "$state/cache/$filename.sig"
    pacman-key --verify "$state/cache/$filename.sig" "$state/cache/$filename"
  done < "$state/package-signatures.txt"
  pacman --config "$bundle/pacman.conf" --dbpath "$state/db" --cachedir "$state/cache" \
    -Sp --needed --print-format '%n %v %h' -- "${optional[@]}" > "$state/rechecked-transaction.txt"
  # Filling the cache changes download sizes, not package identity.
  cmp "$state/package-identities.txt" "$state/rechecked-transaction.txt" || {
    echo 'Package plan changed; return to review.' >&2; exit 1;
  }
fi
[[ "$(readlink -f "$disk_id")" == "$disk" && "$(fingerprint)" == "$identity" ]] || { echo 'Disk identity changed.' >&2; exit 1; }
unused_disk
(cd "$bundle" && sha256sum --quiet -c SHA256SUMS)
progress partition
if [[ "$manual" == true ]];then
  [[ "$(sfdisk --json "$disk" | sha256sum | cut -d' ' -f1)" == "$manual_identity" ]] || { echo 'Partition geometry changed. Return to review.' >&2;exit 1; }
  forynarch-storage list | python "$bundle/install_layout.py" inspect "$disk" "$root_partition_id" "$efi_partition_id" "$register_boot_entry" > "$state/manual-layout-current.json"
  cmp "$state/manual-layout.json" "$state/manual-layout-current.json" || { echo 'Partition assignments changed. Return to review.' >&2;exit 1; }
  mapfile -t partitions < <(jq -r '.efi.path,.root.path' "$state/manual-layout.json")
  mkdir "$state/efi-check"
  mount -o ro "${partitions[0]}" "$state/efi-check"
  existing_loader="$state/efi-check/EFI/Forynarch"
  backup_bytes=0
  if [[ -e "$existing_loader" || -L "$existing_loader" ]];then
    [[ -d "$existing_loader" && ! -L "$existing_loader" ]] || { echo 'The existing Forynarch EFI path is not a regular directory. Inspect it in Partition Manager.' >&2;exit 1; }
    backup_bytes="$(du -sb -- "$existing_loader" | cut -f1)"
  fi
  [[ $(df --output=avail -B1 "$state/efi-check" | tail -1) -ge $((16777216+backup_bytes*2)) ]] || { echo 'EFI needs 16 MiB free plus space to back up any existing Forynarch boot files.' >&2;exit 1; }
  umount "$state/efi-check"
else
  printf '\nFORYNARCH_DISK_WRITE\n'
  printf 'label: gpt\nsize=2GiB,type=U,name=ForynarchEFI\ntype=L,name=ForynarchRoot\n' | sfdisk --wipe always "$disk"
  udevadm settle
  sfdisk --json "$disk" > "$state/partition-table.json"
  nodes="$(python "$bundle/automation_support.py" partitions "$state/partition-table.json" "$disk")"
  mapfile -t partitions <<< "$nodes"
fi
for partition in "${partitions[@]}"; do
  [[ -b "$partition" && "$(lsblk -dn -o PKNAME "$partition")" == "${disk##*/}" ]] || { echo 'Unexpected partition parent.' >&2; exit 1; }
done
progress format
printf '\nFORYNARCH_DISK_WRITE\n'
if [[ "$manual" != true ]];then mkfs.vfat -F32 -n FORYNEFI "${partitions[0]}";fi
mkfs.ext4 -F -L forynarch "${partitions[1]}"
mountroot="$(mktemp -d /run/forynarch-target-XXXXXXXX)"
mount "${partitions[1]}" "$mountroot"
mkdir "$mountroot/$efi_mount"
mount "${partitions[0]}" "$mountroot/$efi_mount"
progress extract
tar --zstd --acls --xattrs --numeric-owner -xpf "$bundle/target-rootfs.tar.zst" -C "$mountroot"
genfstab -U "$mountroot" > "$mountroot/etc/fstab"
printf '%s\n' "$hostname" > "$mountroot/etc/hostname"
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$hostname" "$hostname" > "$mountroot/etc/hosts"
arch-chroot "$mountroot" ln -sfn "/usr/share/zoneinfo/$timezone" /etc/localtime
if ! grep -Eq '^[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8[[:space:]]*$' "$mountroot/etc/locale.gen";then
  printf '\nen_US.UTF-8 UTF-8\n' >> "$mountroot/etc/locale.gen"
fi
arch-chroot "$mountroot" locale-gen
arch-chroot "$mountroot" locale -a | grep -Eqi '^en_US\.utf8$' || { echo 'English locale generation failed.' >&2;exit 1; }
printf 'LANG=en_US.UTF-8\n' > "$mountroot/etc/locale.conf"
progress packages
arch-chroot "$mountroot" pacman-key --init
arch-chroot "$mountroot" pacman-key --populate archlinux
if [[ ${#optional[@]} -gt 0 ]]; then
  cp -a "$state/cache/." "$mountroot/var/cache/pacman/pkg/"
  arch-chroot "$mountroot" pacman -S --needed --noconfirm -- "${optional[@]}"
  arch-chroot "$mountroot" pacman -D --asexplicit -- "${optional[@]}"
fi
if [[ ${#local_files[@]} -gt 0 ]]; then
  python "$bundle/local_applications.py" inventory "$bundle" "$state/selection.json" > "$state/local-rechecked.txt"
  cmp "$state/local-transaction.txt" "$state/local-rechecked.txt"
  for package in "${local_files[@]}"; do
    cp -- "$package" "$mountroot/var/cache/pacman/pkg/"
    arch-chroot "$mountroot" pacman -U --noconfirm -- "/var/cache/pacman/pkg/${package##*/}"
  done
  arch-chroot "$mountroot" pacman -D --asexplicit -- "${local_names[@]}"
fi
progress account
mkdir -p "$mountroot/etc/skel/.config/forynarch"
jq -n --arg layout "$keyboard" '{keyboardLayout:$layout}' > "$mountroot/etc/skel/.config/forynarch/system.json"
case "$keyboard" in gb) console_keymap=uk;;de) console_keymap=de-latin1;;fr) console_keymap=fr-latin9;;br) console_keymap=br-abnt2;;jp) console_keymap=jp106;;id) console_keymap=us;;*) console_keymap="$keyboard";;esac
printf 'KEYMAP=%s\n' "$console_keymap" > "$mountroot/etc/vconsole.conf"
arch-chroot "$mountroot" useradd -m -G wheel -s /bin/zsh -c "$full_name" "$username"
if [[ "$no_password" == true ]]; then
    arch-chroot "$mountroot" passwd -d "$username"
elif [[ "$gui" == true ]]; then
    printf '%s:%s\n' "$username" "$gui_password" | arch-chroot "$mountroot" chpasswd
    unset gui_password
else
    printf 'Set the password for the reviewed account. Input is not logged.\n'
    arch-chroot "$mountroot" passwd "$username"
fi
if (( ${#flatpak_apps[@]} )); then
    progress flatpak
    target_flatpak() {
      # apply_extra needs a real mount root and an unmasked private procfs.
      # The quoted script expands its variables inside the container.
      # shellcheck disable=SC2016
      systemd-nspawn --quiet --directory="$mountroot" --settings=no --register=no --keep-unit \
        --as-pid2 --private-users=no --capability=CAP_SYS_ADMIN --no-new-privileges=yes \
        --pipe --resolv-conf=bind-host /bin/sh -eu -c '
          username=$1; shift
          mount -t proc -o nosuid,nodev,noexec proc /proc
          exec runuser -u "$username" -- env -u XDG_CONFIG_HOME -u XDG_DATA_HOME \
            -u XDG_CACHE_HOME -u XDG_STATE_HOME -u XDG_RUNTIME_DIR -u DBUS_SESSION_BUS_ADDRESS \
            HOME="/home/$username" dbus-run-session flatpak --user "$@"
        ' forynarch-flatpak "$username" "$@"
    }
    target_flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    for flatpak_attempt in 1 2;do
      if target_flatpak install --noninteractive --or-update flathub "${flatpak_apps[@]}" 2>&1 | tee "$state/flatpak-attempt.log";then
        break
      fi
      if [[ "$flatpak_attempt" == 2 ]] || ! grep -Eq '\[(6|7|28|35|52|56)\]|Could not resolve hostname|Couldn.t resolve host name|Network is unreachable|Connection timed out' "$state/flatpak-attempt.log";then
        echo 'Selected Flatpak applications could not be installed. Check the application error above before retrying.' >&2
        exit 1
      fi
      echo 'A temporary network error interrupted selected applications. Retrying once using downloaded content; disk formatting will not be repeated.'
      sleep 3
    done
fi
mkdir -p "$mountroot/etc/sudoers.d"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$mountroot/etc/sudoers.d/10-forynarch-wheel"
chmod 440 "$mountroot/etc/sudoers.d/10-forynarch-wheel"
arch-chroot "$mountroot" visudo -cf /etc/sudoers
if [[ -f "$mountroot/usr/share/forynarch/mkinitcpio.conf.install" ]]; then
  install -m644 "$mountroot/usr/share/forynarch/mkinitcpio.conf.install" "$mountroot/etc/mkinitcpio.conf"
fi
progress bootloader
arch-chroot "$mountroot" mkinitcpio -P
[[ -s "$mountroot/usr/share/grub/themes/forynarch-particle/theme.txt" ]] || { echo 'Missing reviewed GRUB theme.' >&2; exit 1; }
if [[ "$manual" == true ]];then
  if [[ -d "$mountroot/efi/EFI/Forynarch" ]];then
    efi_backup="$(mktemp -d "$mountroot/efi/EFI/Forynarch-backup-XXXXXXXX")"
    cp -a -- "$mountroot/efi/EFI/Forynarch/." "$efi_backup/"
  fi
  arch-chroot "$mountroot" grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Forynarch --no-nvram
  efi_uuid="$(blkid -s UUID -o value "${partitions[0]}")"
  python "$bundle/install_layout.py" boot-entries "$mountroot/efi" "$efi_uuid" > "$state/existing-efi.cfg"
  {
    printf '#!/bin/sh\ncat <<\x27FORYNARCH_EXISTING_EFI\x27\n'
    cat "$state/existing-efi.cfg"
    printf 'FORYNARCH_EXISTING_EFI\n'
  } > "$mountroot/etc/grub.d/42_forynarch_existing"
  chmod 755 "$mountroot/etc/grub.d/42_forynarch_existing"
  if [[ "$register_boot_entry" == true ]];then
    read -r efi_number < "/sys/class/block/${partitions[0]##*/}/partition"
    [[ "$efi_number" =~ ^[1-9][0-9]*$ ]] || { echo 'EFI partition number could not be verified.' >&2;exit 1; }
    efibootmgr --create --disk "$disk" --part "$efi_number" --label Forynarch --loader '\EFI\Forynarch\grubx64.efi'
  fi
else
  arch-chroot "$mountroot" grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Forynarch --no-nvram --removable
fi
arch-chroot "$mountroot" grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot "$mountroot" grub-script-check /boot/grub/grub.cfg
efi_loader="$mountroot/efi/EFI/BOOT/BOOTX64.EFI"
if [[ "$manual" == true ]];then efi_loader="$mountroot/efi/EFI/Forynarch/grubx64.efi";fi
[[ -s "$efi_loader" && -s "$mountroot/boot/grub/grub.cfg" ]] || { echo 'Missing GRUB EFI startup files.' >&2; exit 1; }
[[ -s "$mountroot/boot/vmlinuz-linux" && -s "$mountroot/boot/initramfs-linux.img" ]] || { echo 'Missing boot artifacts.' >&2; exit 1; }
progress verify
mkdir -p "$mountroot/var/lib/forynarch"
cp "$state/selection.json" "$mountroot/var/lib/forynarch/optional-selection.json"
printf '%s\n' "${selected_drivers[@]}" | sed '/^$/d' > "$mountroot/var/lib/forynarch/selected-drivers.txt"
pacman --root "$mountroot" -Q > "$mountroot/var/lib/forynarch/installed-packages.txt"
cat "$state/optional-transaction.txt" "$state/local-transaction.txt" > "$state/combined-transaction.txt"
python "$bundle/automation_support.py" inventory "$bundle/core-packages.txt" \
  "$state/combined-transaction.txt" "$mountroot/var/lib/forynarch/installed-packages.txt"
pacman --root "$mountroot" -Qqe > "$mountroot/var/lib/forynarch/explicit-packages.txt"
{ cat "$bundle/core-explicit.txt"; printf '%s\n' "${optional[@]}" "${local_names[@]}"; } | sed '/^$/d' | sort -u > "$state/expected-explicit.txt"
sort "$mountroot/var/lib/forynarch/explicit-packages.txt" > "$state/actual-explicit.txt"
cmp "$state/expected-explicit.txt" "$state/actual-explicit.txt" || { echo 'Explicit package reasons differ from selections.' >&2; exit 1; }
sync
progress complete
echo 'Forynarch installation completed. Restart to use your installed system.'
echo 'Reboot manually when ready; keep the Live ISO for recovery.'
