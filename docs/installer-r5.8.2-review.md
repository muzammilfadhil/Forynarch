# Installer transaction and live-log correction: R5.8.2

The supplied installation log ends after successful detached-signature checks
with `optional-transaction.txt ... rechecked-transaction.txt differ` and
`Package plan changed; return to review`. This is a concrete pre-partition
failure. It is independent of GPT detection and the earlier output-encoding bug.

## Cause and changes

Pacman 7.1.0 prints the remaining download size for `%s`. The installer compared
`%n %v %s` before and after downloading. A cached package then reports zero bytes,
so an unchanged transaction was rejected. The real Git transaction reproduces
this: all five package sizes become zero while names, versions and hashes remain
identical. For example, perl-error changes from 21,635 bytes to zero.

The recheck now compares **name, version and SHA-256** (`%n %v %h`). Initial transfer
sizes remain available for the review and inventory record. Detached-signature
checks, the frozen bundle, final installed inventory and explicit package reasons
remain enforced. No signature or disk-safety check is disabled. Field syntax is
documented in the [official pacman manual](https://man.archlinux.org/man/pacman.8.en).

Review also offers **Show installation log** during installation and after it
ends. Recent sanitized output is batched up to four times per second, with immediate stage/final flushes and
up to 300 lines / 48K characters retained for the viewer. **Pause updates** freezes the display
while collection continues; **Copy log** copies the displayed excerpt. The full
sanitized log remains at `/run/forynarch-installation/installation.log`. Existing
error details remain available after a failure. Navigation and cancellation stay
locked while disk operations run; log controls remain usable.

The complete CLI test also exposed an extraction failure in dedicated-disk mode:
the ESP mounted at `/boot` could not preserve Linux ACL metadata on FAT32. Dedicated
installation now uses `/efi`, matching prepared installation, and keeps kernels,
initramfs and GRUB configuration in the Linux root's `/boot`. Its removable EFI
loader remains at `EFI/BOOT/BOOTX64.EFI`. Prepared-partition behavior is unchanged.

Affected files are `install-target.sh`, the privileged installer transport,
installer QML, package/cache and transport regressions, native execution fixtures,
and installer documentation. No new package, daemon or installed idle process is
added. Optional developer tools remain opt-in.

## Verification

- **57 targeted tests passed**: 38 installer tests, five prepared-install tests,
  two executable-review tests and 12 partition-preparation tests. Bash syntax,
  ShellCheck and whitespace checks passed. The 17 executor tests additionally
  passed with forced ASCII locale, UTF-8 mode off and locale coercion disabled.
  Coverage includes bounded/redacted/throttled live log events and a password
  matching the internal stage prefix; redaction cannot hide completion markers.

- The real frozen Git transaction rejects the old size comparison after a cache
  fill and accepts the new stable identity comparison. No installation is needed
  for that reproducer.
- A local repository regression runs the actual planning/recheck shell blocks
  against pacman, verifies the warm-cache transition, and rejects changes to name,
  version and hash. This fixture only queries its own unsigned local repository;
  production signature policy remains required.
- The actual CLI completed an installation on an explicitly created 32 GiB sparse
  loop fixture: **exit 0**, all stages through `verify` and `complete`, **60.47
  seconds**, **578 installed packages** (core plus selected Git transaction).
  Read-only postchecks found the kernel/initramfs/GRUB artifacts, the `/efi` FAT32
  mount, Git explicitly selected, no unselected developer groups and no Live sudo
  rule. No personal block device or firmware entry was written.
- The builder lacks the Live hardware-discovery executable, so this fixture
  supplies empty graphics inventory with no drivers selected. Storage checks,
  package download/signatures/recheck, formatting, extraction, account setup and
  bootloader installation execute the actual CLI. The first harness attempt
  stopped at the missing discovery dependency before writing; a subsequent run
  exposed the FAT32 ACL problem above before the final successful run.
- Native Wayland fixtures verify live-log opening while installing, pause/resume,
  actual clipboard content, navigation locking, success, download/Flatpak failure
  and missing-final-report handling. The welcome shader and reduced motion remain
  covered. Fixture confirmation never targets a real disk.

The environment remains pacman 7.1.0, Quickshell 0.3.2, Qt 6.12 and util-linux
2.42.4 with the cached 18 October Arch snapshot. Actual laptop installation and
firmware acceptance, and full Chrome/Zoom/VS Code Flatpak acceptance, remain open.
No new installed idle-memory benchmark or disposable-loop boot claim is made.

## UI delivery check

Antislop DURING retains the established navy Review layout, 44 px controls,
keyboard focus and high-contrast plain-text log viewer. No image, icon download,
looping motion, terminal renderer or polling service is added. The viewer uses
bounded push updates and supports pausing to read/select output. Error state is
textual and includes real process results; it does not fabricate progress.

## Final R5.8.2 artifact

The ISO is 3,839,197,184 bytes. Builder and Windows SHA-256 matched:
`505496637ef6fe1ca44fe967c35fbae87e51083628558ae6bde64cf3add6cdc3`.
A fresh UEFI boot verified the actual Live executors and liveuser installer QML
against source hashes, executor availability and absence of target disks.
The actual Live helper retained valid UTF-8 under a forced ASCII caller and
published live-log events plus the real child exit result. Native log pause,
unique clipboard-content copy and failure/interruption fixtures passed on that
Live runtime. Physical laptop acceptance remains separate.
