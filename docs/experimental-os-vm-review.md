# Existing-OS VM implementation review — R4.7

This repository report is updated after build and QA. The copy bundled in the
ISO is an earlier build-time snapshot; use the adjacent ISO `.sha256` file and
this repository copy for final artifact identity and acceptance results.

## Intent and affected files

Provide opt-in existing-OS virtualization in installer software choices and
Settings. The implementation consists of `forynarch_vm.py` (validated plans and
GPT mapping), `forynarch-vm.py` (per-user settings),
`forynarch-vm-service.py` (authenticated preparation and supervision), the
Virtual Machines QML page, fixed polkit policy, UDisks exclusion rule, desktop
entry, optional catalog and integration scripts. The AGENTS scope update records
the user's explicit request without relaxing core package or memory rules.

## Versions and assumptions

Arch builder: QEMU 11.1.2-1, edk2-ovmf/edk2-shell 202608-1,
device-mapper 2.03.43-2, NTFS-3G/ntfsprogs 2026.9.28-1,
swtpm 0.10.2-1, systemd 262-1. Desktop testing uses Hyprland 0.56.2-4,
Quickshell 0.3.2-1 and Qt 6.12. Current Arch splits `mkntfs` and `ntfsls`
into ntfsprogs, which is included in the optional group.

Production requires KVM, GPT, a supported EFI loader, an unmounted OS partition
and sufficient free RAM/storage. Nested builder fixtures use explicit internal
TCG/headless arguments; these are unavailable through the public helper/API.

## Implemented behavior

- Installer group unchecked; feature independently disabled by default.
- No VM stack added to core, no autostart or libvirt service.
- Fresh authenticated review, stable disk identity and shutdown acknowledgement.
- Preview uses a disposable overlay; Direct requires a clean Windows NTFS
  installation, backup acknowledgement and typed confirmation every launch.
- Only the selected OS partition is mapped. Private GPT/EFI/firmware files
  replace host metadata; other disk extents fail reads.
- Reject active mounts, swap, holders, host ancestry, encryption for Direct,
  stale review and competing raw-device handles. Short-lived device probing
  receives a bounded wait; persistent handles block launch.
- QEMU and swtpm run as the requesting user without capabilities. Physical
  source descriptors stay in the supervisor; the guest receives managed views.
- systemd supervises guest lifetime independently of Settings. Crash cleanup
  checks mapping ownership; removal retries temporary udev opens without force.
- Configuration removal cannot hide active managed resources from disable
  checks; shutdown/recovery remain available even with the feature disabled.

## Tests and results

On the Arch builder, `python -m unittest discover -s tests -q` completed
**203 tests, OK, 2 skipped**. The skipped tests require native Zsh and were
previously checked in the target chroot. Generated hotkey validation, Bash
syntax and ShellCheck of desktop integration passed. Windows VM-model tests:
**10 tests, OK**. `git diff --check` passed. The full suite on Windows is not
an acceptance result: it has Linux-only skips and a native-path widget test
failure; the Arch run is the applicable full-suite result.

Native block fixtures on the verified builder scratch filesystem passed:

1. `PREVIEW_SOURCE_UNCHANGED_HOST_MASKED_EXCLUSIVE_CLAIM_OK`
2. `QEMU_UNPRIVILEGED_OVMF_PREVIEW_EXIT_AND_CLEANUP_OK`
3. `SUPERVISOR_CRASH_CGROUP_AND_EXECSTOPPOST_CLEANUP_OK`
4. `DIRECT_WRITES_ONLY_SELECTED_FIXTURE_PARTITION_OK`
5. `QEMU_GTK_WAYLAND_WINDOW_AND_PIPEWIRE_CLIENT_OK`

The fixture creates its own file-backed GPT disk with EFI, NTFS and mounted
host sentinel partitions. Source hashing, exclusive claims, hidden-host I/O,
unprivileged process identities/capabilities, inherited descriptors, QMP exit,
overlay disposal, crash cgroup cleanup and Direct write boundaries are checked.
The QEMU screenshot showed the real OVMF UEFI Shell. No personal disk was used.

A second run used Weston 15.0.1 with its headless Pixman backend and PipeWire
1.6.9 on the builder. The scene graph contained the QEMU process's mapped
window, and the PipeWire registry contained its client. This exercises the
production GTK/Wayland environment and audio connection, while still using
TCG and a disposable disk. Audible playback and real desktop input are not
established by a registry check.

This test found that `spawn=deny` prevents GTK's sandboxed Glycin SVG loader
from starting and aborts the GUI. Graphical QEMU therefore permits subprocess
creation while retaining the obsolete/elevation/resource-control seccomp
restrictions and unprivileged identity. Headless fixtures retain `spawn=deny`.
The regression test checks both command variants. Weston and test tooling were
installed only on the builder, not in the target or Live image.

Native Quickshell flow passed `VM_CONFIG_REVIEW_AND_DIRECT_CONSENT_OK`: factory
off, enable, create/save, review, blocked incomplete Direct consent, valid typed
consent and launch request. Its command backend is deliberately a data-only test
double; the separate block fixture tests the privileged backend.

## ISO artifact

R4.7: `out/iso/forynarch-2026.10.16-blue-hour-r4.7.iso`
(3,966,468,096 bytes).
SHA256: `dbbd3f8fcd3a24859d3f95c697509b79215de157083b5abbaf4c806da5a4b56e`.
Builder and Windows checksums match. The staged target and Live roots match
the VM helpers, model, QML page and optional catalog. Installer bundle checksum
validation passed, including its updated catalog and package planner. Core
package checks found no QEMU or swtpm, Git, Node.js/npm, Foot or Chafa.

The exact final ISO cold-booted in the diskless 3,072 MiB / two-vCPU QA VM:
`EXACT_R47_COLD_BOOT_OK`. Checks found one Hyprland session, no compositor
configuration errors, executable VM helpers, installed polkit policy, factory
feature state off, no saved/active VMs, and the optional group unchecked. The
Direct-consent QML flow also passed again on this final cold-booted session.
VirtualBox software rendering reports its known DMA-BUF/SHM fallback warning;
the Settings page loads without a QML type error.

## Remaining acceptance work

Actual Windows/KVM boot, SATA/NVMe driver behavior, activation, BitLocker,
Secure Boot expectations, guest shutdown/native boot afterwards, multi-disk and
4Kn hardware still require dedicated tests with a backed-up installation.
Real Hyprland guest-window input and audible PipeWire playback remain untested.
The feature remains experimental for these reasons. Settings UI testing does
not prove Windows compatibility.

Installed-core idle memory must be remeasured separately with all guests
stopped. A Live ISO snapshot cannot establish the installed 3 GB memory gate.
Guest allocations are additional and must be reported separately.

The pre-GTK-fix R4.7 candidate (SHA256 `60868dbd29dc5a9a9797635a093604f033741391f0ef4109ce776f905dd5d886`)
was cold-booted with 3,072 MiB RAM, two vCPUs and no hard disk. After closing
Welcome and Settings and waiting five minutes, six samples at five-second
intervals recorded `MemTotal - MemAvailable`:
1,272,537,088; 1,272,336,384; 1,271,554,048; 1,271,554,048;
1,268,592,640; 1,268,838,400 bytes. Swap was zero throughout. This is a Live
candidate snapshot; the final artifact receives a separate cold-boot check.

Primary references are linked in the [implementation contract](experimental-os-vm.md).
Device-mapper removal follows the documented non-forcing
[`--retry` behavior](https://man7.org/linux/man-pages/man8/dmsetup.8.html).
