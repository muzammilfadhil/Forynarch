#!/usr/bin/env bash
# Install an Arch builder ONLY onto a verified blank 80 GiB VirtualBox disk.
set -euo pipefail
export LC_ALL=C
approve_disk=false approve_packages=false approve_admin=false public_key=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --approve-blank-vm-disk) approve_disk=true ;;
    --approve-builder-packages) approve_packages=true ;;
    --approve-builder-admin) approve_admin=true ;;
    --public-key) [[ $# -ge 2 ]] || exit 2; public_key="$2"; shift ;;
    --help)
      echo 'Only a fresh 80 GiB VirtualBox VM with one blank disk is supported.'
      echo 'Required: --approve-blank-vm-disk --approve-builder-packages --approve-builder-admin --public-key FILE'
      echo 'Creates GPT/ext4 + EFI, installs Arch/build tools, and builder SSH-key administrator with passwordless sudo.'
      exit 0 ;;
    *) echo 'Unknown provisioning option.' >&2; exit 2 ;;
  esac
  shift
done
[[ "$approve_disk" == true && "$approve_packages" == true && "$approve_admin" == true ]] || {
  echo 'Explicit virtual-disk, builder-package and administrator approval required.' >&2; exit 2;
}
[[ "$(id -u)" == 0 && "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && -d /sys/firmware/efi ]] || exit 1
[[ -r /sys/class/dmi/id/product_name && "$(cat /sys/class/dmi/id/product_name)" == VirtualBox ]] || {
  echo 'This provisioning script refuses non-VirtualBox hardware.' >&2; exit 1;
}
[[ -f "$public_key" ]] || { echo 'SSH public key missing.' >&2; exit 1; }
[[ "$(wc -l < "$public_key")" == 1 ]] || exit 1
grep -Eq '^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( .*)?$' "$public_key" || exit 1
ssh-keygen -lf "$public_key" >/dev/null
disk_text="$(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1}')"
mapfile -t disks <<< "$disk_text"
[[ ${#disks[@]} == 1 && -b "${disks[0]}" ]] || { echo 'Exactly one VM disk is required.' >&2; exit 1; }
disk="${disks[0]}"
[[ "$(blockdev --getsize64 "$disk")" == 85899345920 ]] || { echo 'VM disk size does not match approved 80 GiB.' >&2; exit 1; }
[[ "$(lsblk -dn -o MODEL "$disk" | xargs)" == 'VBOX HARDDISK' ]] || exit 1
[[ -z "$(wipefs --no-act --noheadings --output TYPE "$disk")" ]] || { echo 'Disk is not blank; existing data will not be overwritten.' >&2; exit 1; }
[[ "$(lsblk -nrpo NAME "$disk" | wc -l)" == 1 ]] || { echo 'Existing partitions found.' >&2; exit 1; }
mounted="$(findmnt -rn -o MAJ:MIN)"
major="$(lsblk -dn -o MAJ:MIN "$disk")"
if grep -Fqx "$major" <<< "$mounted"; then echo 'VM disk is mounted.' >&2; exit 1; fi
[[ -z "$(find "/sys/class/block/${disk##*/}/holders" -mindepth 1 -maxdepth 1 -print -quit)" ]] || exit 1
repositories="$(pacman-conf --repo-list)"
while IFS= read -r repository; do
  case "$repository" in core|extra|multilib) ;; *) echo 'Nonstable repository refused.' >&2; exit 1 ;; esac
done <<< "$repositories"
curl -fsI --connect-timeout 20 https://archlinux.org/ >/dev/null
echo 'Approved: install Arch builder on the verified new VirtualBox-only disk.'
printf 'label: gpt\nsize=2GiB,type=U,name=BuilderEFI\ntype=L,name=BuilderRoot\n' | sfdisk "$disk"
udevadm settle
case "$disk" in *[0-9]) efi="${disk}p1"; root="${disk}p2" ;; *) efi="${disk}1"; root="${disk}2" ;; esac
for partition in "$efi" "$root"; do
  [[ -b "$partition" && "$(lsblk -dn -o PKNAME "$partition")" == "${disk##*/}" ]] || exit 1
done
mkfs.vfat -F32 -n BUILDEFI "$efi"
mkfs.ext4 -F -L builderroot "$root"
destination="$(mktemp -d /run/forynarch-builder-XXXXXXXX)"
cleanup() {
  if mountpoint -q "$destination/boot"; then umount "$destination/boot" || true; fi
  if mountpoint -q "$destination"; then umount "$destination" || true; fi
}
trap cleanup EXIT
mount "$root" "$destination"
mkdir "$destination/boot"
mount "$efi" "$destination/boot"
# Developer tooling belongs to this builder VM, never the installed Forynarch core.
pacstrap -K "$destination" base linux linux-firmware networkmanager openssh sudo \
  archiso arch-install-scripts python lua shellcheck zstd dosfstools e2fsprogs \
  qemu-system-x86 edk2-ovmf unzip
genfstab -U "$destination" > "$destination/etc/fstab"
printf 'forynarch-builder\n' > "$destination/etc/hostname"
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 forynarch-builder\n' > "$destination/etc/hosts"
sed -i 's/^#en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' "$destination/etc/locale.gen"
arch-chroot "$destination" locale-gen
printf 'LANG=en_US.UTF-8\n' > "$destination/etc/locale.conf"
printf 'KEYMAP=us\n' > "$destination/etc/vconsole.conf"
arch-chroot "$destination" ln -sfn /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
arch-chroot "$destination" useradd -m -G wheel -s /bin/bash builder
# Random local password is not stored/displayed; remote access is SSH key only.
account_password="$(head -c32 /dev/urandom | base64)"
printf 'builder:%s\n' "$account_password" | arch-chroot "$destination" chpasswd
unset account_password
mkdir -p "$destination/home/builder/.ssh" "$destination/etc/ssh/sshd_config.d" "$destination/etc/sudoers.d"
install -m600 "$public_key" "$destination/home/builder/.ssh/authorized_keys"
chmod 700 "$destination/home/builder/.ssh"
arch-chroot "$destination" chown -R builder:builder /home/builder/.ssh
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\nAllowUsers builder\n' > "$destination/etc/ssh/sshd_config.d/10-forynarch-builder.conf"
printf 'builder ALL=(ALL:ALL) NOPASSWD: ALL\n' > "$destination/etc/sudoers.d/10-forynarch-builder"
chmod 440 "$destination/etc/sudoers.d/10-forynarch-builder"
arch-chroot "$destination" visudo -cf /etc/sudoers
arch-chroot "$destination" systemctl enable NetworkManager.service sshd.service
arch-chroot "$destination" mkinitcpio -P
arch-chroot "$destination" bootctl --esp-path=/boot --no-variables install
uuid="$(blkid -s UUID -o value "$root")"
mkdir -p "$destination/boot/loader/entries"
printf 'default arch-builder.conf\ntimeout 2\neditor no\n' > "$destination/boot/loader/loader.conf"
printf 'title Arch Forynarch Builder\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=UUID=%s rw\n' "$uuid" > "$destination/boot/loader/entries/arch-builder.conf"
[[ -s "$destination/boot/vmlinuz-linux" && -s "$destination/boot/initramfs-linux.img" ]] || exit 1
pacman --root "$destination" -Q > "$destination/home/builder/builder-packages.txt"
arch-chroot "$destination" chown builder:builder /home/builder/builder-packages.txt
sync
echo 'Builder installation commands completed. Reboot and SSH verification are still required.'
