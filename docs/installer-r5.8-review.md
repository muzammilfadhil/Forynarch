# Installer package correction: R5.8

The optional-software transaction shown in the laptop report resolves to 196
repository packages plus the reviewed Mudil Music package and three Flatpak
applications. Fifteen repository filenames contain an Arch epoch separator
(`:`). The previous signed-package filename guard rejected these valid names
before partitioning, including Discord, Docker, Go and Flatpak. The downloaded
snapshot reproduces that rejection. The laptop log was unavailable, so this
reproduction does not prove it was the only failure on that machine.

## Changes

- The filename guard accepts `:` while continuing to reject separators, absolute
  paths, hidden paths, whitespace and shell syntax. Signature verification is
  unchanged; package trust is not relaxed.
- The privileged transport records the failed stage, exit code, bounded output
  tail, log location and conservative disk state. Account secrets and terminal
  escape sequences are removed from logs and reports. Reports are root-only.
- Review offers expandable, selectable error details and a copy action. A failed
  attempt no longer leaves the unconditional ?No disk changes applied? footer.
  An incomplete transport report leaves the disk state unknown. Storage review
  refreshes retain the failure report.
- Flatpak retries its selected application transaction once for transient network
  errors, using downloaded content. Permission and verification failures do not
  trigger that retry; partitioning and formatting are never retried by this loop.
- The executor emits a marker before destructive operations and gives Flatpak
  application installation its own progress stage. Existing confirmation,
  identity, mount, GPT, EFI-preservation and package-selection rules remain.
- No service or background process is added. Optional groups remain opt-in;
  the isolated software test root is never used as the installed-core payload.

Main files: `scripts/install-target.sh`, `scripts/forynarch-install-system.py`,
`config/quickshell/forynarch-installer/shell.qml`, installer executor/package tests
and native execution fixtures.

## Verification

Tested against pacman 7.1.0/libalpm 16.0.1, Quickshell 0.3.2, Qt 6.12,
util-linux 2.42.4 and the cached Arch package snapshot from 18 October 2026.

- **50 targeted tests passed**: 31 installer tests, five prepared-install tests,
  two executable-review tests and 12 partition-preparation tests. Bash syntax
  and ShellCheck completed with exit 0.
- All **196 repository packages downloaded**, exit 0 (429.00 seconds). The old
  guard rejects 15 filenames; the patched executor guard accepts all 196.
  All 196 embedded signatures independently verified with `pacman-key`, exit 0
  (20.38 seconds for the guard/signature pass). The Mudil package manifest and
  archive inventory also passed. These checks perform no block-device writes.
- Native Wayland fixtures passed navigation, finite/reduced welcome motion,
  account validation, confirmation focus, private stdin handoff, completion,
  pre-write download failure and post-write Flatpak failure. These use a fake
  executor and never format a disk.
- Error text/focus contrast is 15.08:1 against its background; selected text is
  6.24:1. Error details support keyboard focus and text selection.

## Limits and recovery

The isolated rootfs successfully installed all repository selections and Mudil
Music: **770 packages**, with exact inventory and explicit-install reasons matching
the reviewed core plus transaction. The independent core remains unchanged.
The first fixture setup omitted the required root bind mount; its package-space
check stopped before installation. The corrected fixture uses a mounted root.

The first Flatpak application transaction stopped on a transient DNS failure.
A subsequent curl/Flatpak check worked with the existing resolver configuration.
The small Adwaita-dark Flatpak extension installed successfully. The subsequent
full three-application runtime download was stopped in the isolated QA root to
finish producing the installer correction; full Chrome/Zoom/VS Code installation
and launch acceptance is **not claimed**. Unit tests verify the bounded retry
for transient, persistent and permission errors. Final image assembly is recorded
separately. Physical-laptop firmware, storage and network acceptance
remain separate from the VM/rootfs tests. The prior R5.7 prepared-partition
installation and installed boot evidence is documented separately; this patch
has not repeated that real partition-writing test. No new installed idle-memory
benchmark is claimed.

In the updated Live installer, choose **Show error details** after a failure and
**Copy error details** to retain the report. The Live session also supports:

```sh
pkexec /usr/local/libexec/forynarch-install-system --diagnostics
sudo -n tail -n 80 /run/forynarch-installation/installation.log
```

Keep the Live USB available if disk writes may have begun. Correct the reported
cause and refresh storage review before another attempt. An installation retry
still requires its own account validation and disk-specific confirmation.

The filename and signature fields follow the official
[pacman manual](https://man.archlinux.org/man/pacman.8.en); no unsigned-download
fallback or database refresh is introduced.

## UI delivery check

Antislop DURING uses the existing owner-approved installer direction. The change
extends the existing Review form, navy/pale-blue palette, 44 px buttons and
visible keyboard focus. It adds no decorative cards, looping motion, asset
fetches or persistent processes. Native UI verification and the contrast checks
above cover the changed controls; physical accessibility acceptance remains open.

## Final image

`forynarch-2026.10.18-blue-hour-r5.8.iso` was assembled on 19 October using
the cached 18 October Arch snapshot. `mkarchiso` returned **0**. The copied image
is **3,839,197,184 bytes**, and its host SHA-256 matches the builder:

```text
32d075b97aac797f9ed9c142414451e74967a9d79e1b51178a0ccfd0a96331a4
```

The SquashFS image contains byte-identical copies of the patched CLI, privileged
transport and installer QML. Its independent target remains **573 core packages**,
with Git, Node.js, npm, Docker, Rustup, Go, Flatpak, VS Code and Mudil absent.
The 770-package optional QA root is separate and is not part of this payload.

The final image also booted through UEFI into the Live Hyprland desktop and
Try/Install Welcome in VirtualBox. Live discovery reports the executor available;
the live user's installer QML and both executors match the patched source.
Fresh-session diagnostic state is empty, as expected. This boot VM has no target
disks attached. Screenshot: `out/virtualbox/r58-live-boot.png` (generated output).
