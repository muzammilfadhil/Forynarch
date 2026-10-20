# Forynarch installer

The standalone Live installer performs real installation through a privileged,
private-stdin transport. Its nine stages are Welcome, Connection, Location,
Keyboard, Storage, Account, Drivers, Software and Review. It is not a preview
wizard. A review is deliberately read-only until the user confirms its exact
physical target.

## Storage

| Method | Disk changes |
| --- | --- |
| Use an entire disk | Replace the selected disk with GPT, a FAT32 ESP and an ext4 root. |
| Install alongside another OS | Format the prepared Linux root, reuse the selected ESP, preserve other partitions. |
| Use prepared partitions | Use the same root/ESP assignment executor without assuming another OS is present. |

Alongside installation does not automatically shrink another OS. Open KDE
Partition Manager from Storage, apply the desired layout there, return and
refresh disks. Root and ESP currently have to be on the same disk. Root needs
at least 32 GiB; the FAT32 ESP needs at least 100 MiB and 16 MiB free plus room
to back up any existing Forynarch loader. Separate `/home`, Linux encryption,
automatic filesystem shrinking and legacy BIOS installation are not offered.

Storage shows the current UEFI/Legacy boot mode separately from the detected
partition-table type. A GPT disk can still be accessed from a Legacy Live boot;
restart the USB in UEFI mode in that case. Secure Boot is checked before the
final page and is not supported by this image.

The inventory reads GPT metadata directly in the passwordless Live environment.
It handles standard GPT metadata reservations using the logical sector size;
valid partitions do not need an artificial 1 MiB gap at the end of the disk.
Kernel START values are 512-byte sectors even on 4Kn drives. Estimates do not
authorize disk changes: prepared installation also runs `sfdisk --verify`, checks
actual filesystem signatures and rechecks the partition-table fingerprint.

Mounted, encrypted, recovery, Windows data and current-system partitions cannot
be selected as the root format target. Volumes on the target disk must be
unmounted before installation. Whole-disk erasure requires its own affirmative
confirmation and is never selected automatically.

For both dedicated and prepared installation, kernels remain in the Linux root's `/boot`; the ESP
mounts at `/efi`. Existing EFI loaders and firmware entries are retained. Existing
Forynarch loader files are copied into a unique `EFI/Forynarch-backup-*` directory
before replacement. That backup does not appear as a second OS in GRUB. Registering
a Forynarch firmware entry is a separate visible choice.

## Account and optional packages

Account names, full names, hostnames and passwords are validated in both the UI
and transport. Passwords travel through stdin, never argv, IPC status or logs.
No password means local passwordless sign-in, without automatic login.

Git, Node.js, npm, Python developer tools and other optional software start
unchecked. Live applications are not copied wholesale into the installed system.
The independent core payload is checksummed, and optional repository packages are
planned, downloaded and signature-checked before destructive disk operations.

The matching Intel or AMD Vulkan package is selectable online and reaches the
same signed package transaction as optional software. NVIDIA proprietary drivers
and generation-specific Intel video acceleration require additional hardware
checks and are labelled for configuration after installation. Unimplemented
choices cannot be selected and then silently ignored.

## Failures and recovery

Review and execution preserve every storage safety blocker. The UI distinguishes
unknown/non-GPT tables, invalid partition bounds, Legacy boot, Secure Boot,
missing payloads and stale inventories. The transport revalidates the plan and
reports public preflight reasons without exposing account secrets. An installation
failure never reports completion. During installation, **Show installation log**
opens recent sanitized output. **Pause updates** freezes the view without stopping
the installer, and **Copy log** copies the displayed excerpt. The viewer retains
up to 300 lines / 48K characters; the complete log remains on disk. **Show error details** displays its failed
stage, exit code and sanitized output; **Copy error details** copies the report.
The footer distinguishes a stopped pre-write attempt from a disk that may have
changed, and treats a missing final report as unknown. Retain the Live USB and
inspect `/run/forynarch-installation/installation.log` before retrying. A root-only
report can also be read with
`pkexec /usr/local/libexec/forynarch-install-system --diagnostics`.

See [installation and dual boot](wiki/install-and-dual-boot.md) and
[R5.8.2 transaction and live-log review](installer-r5.8.2-review.md) for current evidence and limits.

## Runtime and verification

The supported native UI uses Quickshell 0.3.2 and Qt 6.12. Device discovery was
checked with util-linux 2.42.4. Source regression tests cover GPT tail partitions,
512-byte and 4Kn metadata, prepared-root assignment without extra unallocated
space, stale or mounted targets, driver package allowlists and secret isolation.
A sparse GPT test image is disposable; no personal disk is used.

Native QML fixtures exercise storage messages, all nine page Loaders, account
validation, secret handoff, confirmation focus and progress/completion. Installation
and reinstall checks belong on explicitly identified disposable UEFI VM disks.
Real laptop firmware, Secure Boot signing, encrypted installation and arbitrary
proprietary graphics hardware require their own acceptance work. Real execution
is implemented; broader hardware certification is not implied by that fact.
