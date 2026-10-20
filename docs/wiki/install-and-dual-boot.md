# Install Forynarch and keep another OS

Boot the Live USB in **UEFI mode** and open **Install Forynarch**. The installed interface uses English. Optional applications and developer tools are installed only when selected.

## Choose a storage method

| Method | Result |
| --- | --- |
| Erase disk | Erases the selected whole disk and creates a new EFI partition and ext4 Linux root. |
| Install alongside | Uses root and EFI partitions you have already prepared; preserves all other partitions. |
| Use prepared partitions | Assigns an existing Linux root partition and a shared EFI System Partition. |

The last two methods currently use the same prepared-partition executor. They do not automatically shrink another OS, encrypt Linux, or create a separate `/home`.

The Storage page shows **Live boot mode** separately from the disk's GPT type.
A GPT disk can be present in a Legacy/BIOS session; restart the USB in UEFI mode
if shown. Valid GPT layouts may end close to the end of the disk. They do not
need a 1 MiB trailing gap, and prepared installation does not require another
32 GiB unallocated region after the Linux root partition has been created.

1. Back up important files and keep encryption recovery keys available. Check the drive model and capacity.
2. To retain another OS, prepare free space with that OS's filesystem tools first. For Windows, use Disk Management to shrink its volume and perform a full shutdown; disable Fast Startup before sharing NTFS data. Do not format Windows, recovery, reserved or existing EFI partitions.
3. In the installer's **Storage** step, open **Partition Manager**. KDE Partition Manager can prepare the unallocated space. Create a Linux filesystem partition of at least **32 GiB** with the Linux filesystem GPT type. Apply its queued operations before returning to the installer. Applying operations in KDE is a separate disk-write confirmation.
4. Refresh the installer. Choose the new Linux partition as **Root**. Its entire contents will be formatted as ext4. Choose an existing, unmounted FAT32 EFI System Partition of at least **100 MiB**, with at least **16 MiB free**. It is preserved, not reformatted. Root and EFI must currently be on the same GPT disk.
5. Choose whether to add a **Forynarch firmware boot entry**. Existing firmware entries and EFI files are retained. If disabled, use the firmware's boot-file picker to launch `EFI/Forynarch/grubx64.efi` from the selected EFI partition.
6. Review the physical partition paths and type the requested disk-specific confirmation. Installation formats only the chosen root. Kernel files remain in the Linux root's `/boot`; the shared EFI partition mounts at `/efi`.

GRUB adds entries for recognized existing Microsoft and Linux EFI loaders. This does not unlock BitLocker or replace another OS's bootloader. A firmware change may cause an encrypted OS to request its recovery key. Actual firmware and existing-OS boot behavior still require hardware testing. Secure Boot installation is not currently supported.

The graphical editor is KDE Partition Manager; `gdisk` is also available for experienced users. Do not run partition commands copied from another machine without verifying your own target.

For reinstalling onto a prepared root, existing Forynarch EFI files are backed
up into a unique `EFI/Forynarch-backup-*` directory before replacement. Leave
additional free space for that copy. Other EFI loaders are kept. Unmount volumes
on the target disk before starting; do not force an unmount of the Live USB.

## Live administration

The disposable Live account belongs to `wheel` and has passwordless sudo. Installer and partition-manager authorization does not ask for a Live password. In its interactive Zsh, `pacman` and `gdisk` automatically invoke `sudo -n`; you do not need a root shell for those commands. Other administrative commands can use `sudo -n command`.

This policy is confined to Live media. The independently installed system does not inherit the Live sudoers rule or its automatic authorization policy.

References: [KDE Partition Manager handbook](https://docs.kde.org/stable_kf6/en/partitionmanager/partitionmanager/usermanual.html), [GNU GRUB EFI installation](https://www.gnu.org/software/grub/manual/grub/html_node/Installing-GRUB-using-grub_002dinstall.html).
