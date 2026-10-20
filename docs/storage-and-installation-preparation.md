# Storage management and installation preparation

Update: installation setup now lives in a [separate application](standalone-installer.md).
The embedded Settings installation tab described in earlier iterations below
has been removed. Storage retains disk inspection, proposals and the advanced
partition editor. Forynarch supports standalone installation as a product goal;
alongside setup is not specific to Windows.

## Standard advanced editor — 15 October 2026

The user-requested **KDE Partition Manager** is explicitly included in the target
core proposal and therefore the derived Live profile. It remains available as a
standard application alongside the friendly Storage interface. This selection
does not enable any developer package group.

Storage → **Open advanced** launches `scripts/forynarch-partitions.sh` and closes
Settings so the editor is visible. The wrapper accepts no disk arguments, refuses
root-session launches and performs no elevation. Native Polkit authorization and
pending-operation review stay with KDE Partition Manager. The preparation wizard
remains non-executable. Filesystem operations require appropriate installed tools
and a suitable filesystem state; availability must be checked per operation.

Verified repository versions: `partitionmanager` and `kpmcore` **26.08.2-1**.
The actual Live transaction added 34 packages: **25.97 MiB downloaded / 144.82 MiB
installed**, with no Git, Node.js, npm or Python additions. The existing target
dependency audit remains required on rebuild. See the
[Arch package](https://archlinux.org/packages/extra/x86_64/partitionmanager/) and
[KDE application description](https://apps.kde.org/partitionmanager/).

`config/forynarch/partition-manager.qss` gives the Storage-launched editor a scoped
navy palette, using Qt's stylesheet argument. No theme daemon or Plasma session
is added. The upstream application launcher uses the user's own Qt theme.

The real editor was launched through the Storage button and its window/palette
inspected. The passwordless Live user is not an administrator; device discovery
requires native privileged authentication. No permission bypass, account change,
disk write or queued partition operation was performed. Authenticated discovery
and actual create/resize/format/delete remain disposable-VM tests with an
authorized administrator and verified empty disk. The Archiso cowspace limit was
raised from 256 to 512 MiB in RAM to fit packages, without resizing any disk.
The existing ISO was not rebuilt.

Four boundary tests cover missing editor, permitted launch arguments, rejected
disk/operation arguments and root-session refusal. Native suite: **94 tests, OK**.
After closing the editor and Settings, six Live samples peaked at
**1,910,747,136 bytes**, swap **0**. This includes temporary package/source files
and is not an installed-core benchmark. Next: version-checked installer backend,
then separately authorized UEFI disposable-disk tests. The existing whole-disk CLI
must not be used as an alongside backend.

## Earlier preparation iteration

15 October 2026. This iteration prepares the interface, discovery and proposal
contract. **It does not implement partition writes or a graphical installation
executor.** The existing dedicated-disk CLI installer remains independent and
is never called by these new screens.

## Delivered interface

Settings → Storage now has three views, using the existing Glass shell:

1. **Disks & partitions:** real detected hard disks, model, path, capacity,
   transport/table metadata, a partition diagram and partition filesystem,
   size, use/protection/encryption information. Estimated gaps are shown only
   for a conservative, consistent GPT geometry. Unknown is not treated as empty.
2. **Plan changes:** prepare a create, resize, format or delete proposal. The
   selected target, filesystem/size request, blocking conditions and remaining
   checks are shown. There is no Apply operation in this preview.
3. **Install Forynarch:** Method → Software → Review. Methods are alongside an
   existing OS, entire disk, or manual partitioning. A Live-only application
   entry opens this preparation view directly. It never launches an erase command.

This Computer remains the file-access view, including verified Windows letters
and existing safe mount policy. Its folder button is available from Storage.
Disk administration and ordinary file access have separate interfaces.

The installer preparation starts with no optional software selected. Offline
planning enables core only; there is no verified optional offline bundle.
Online planning enables explicit group selections, but does not download or
install anything. Back/Next preserves selections. Developer packages are not
added to the target by opening or navigating any of these screens.

The wizard is deliberately incomplete as an installer: region, account/password,
encryption, actual mount-point assignment, installation progress, recovery and
reboot remain future stages. Their omission is not a release claim. The source
vision's shared-data partition and Windows boot preservation remain required.

## Source and technical boundaries

- `StoragePage.qml`: on-demand interface; no polling daemon. Read-only storage
  IPC reports stage/counts/selections/proposal blockers for verification.
- `forynarch-storage.sh`: only `list` and `review JSON`. Uses `lsblk`, jq and a
  snapshot revision. It has **no execute verb**, elevation, filesystem tools,
  partition-writing commands, mounting, unmounting, EFI edits or package calls.
- `storage-inventory.jq`: models physical/virtual hard disks and partition
  metadata. Optical media and loop devices are not installation targets.
  WWN/serial/table identity is checked for uniqueness; transient paths alone
  cannot establish an executable target identity.
- `storage-plan.jq`: typed requests against fresh inventory and the existing
  optional-software catalog. Every result has `reviewOnly: true` and
  `canExecute: false`, including otherwise plausible layouts.
- `forynarch-setup.sh` and `forynarch-install.desktop`: Live preparation entry;
  installed sessions are directed to boot Live media.
- Target/Live staging installs the models and catalog with Bash/jq helpers.
  No new target Python helper, package dependency or resident service was added.

`lsblk` is used with explicit columns, bytes and tree JSON, following its
[official manual](https://man.archlinux.org/man/lsblk.8.en). The model uses the
kernel's 512-byte START sector convention, independently of logical sector
size. Estimated gaps reserve 1 MiB at each end and reject overlapping/out-of-
bounds partition metadata, whole-device filesystems and unknown/non-GPT tables.
These estimates are **not verified allocatable extents**: an executor must read
the authoritative table, sector geometry, alignment and usable boundaries again.

The revision covers the discovered model, not filesystem free-space estimates.
A request for an older revision is blocked. Duplicate stable IDs are blocked.
Mounted, current-system, boot/reserved/recovery, encrypted and read-only
partitions remain protected. Resize always requires additional offline health
and filesystem-specific limit checks; this preview does not infer shrink limits.

NTFS/BitLocker metadata can indicate a Windows-compatible layout; it does not
prove that a working Windows installation or bootloader has been found.
Filesystem contents, recovery keys and NVRAM were not read to pretend otherwise.
No installation eligibility claim is made from partition labels or C:/D: aliases.

## Dual-boot strategy and research

Use the existing [Calamares framework](https://calamares.io/about/) as the
preferred execution candidate after selecting, installing and checking an exact
release on the builder. Its distribution integration still needs a tested
minimal-rootfs and package-selection bridge. No new Calamares configuration or
module syntax was invented in this iteration.

[KDE Partition Manager](https://docs.kde.org/stable_kf6/en/partitionmanager/partitionmanager/index.html)
and [GParted's manual](https://gparted.org/display-doc.php?name=help-manual)
inform the device/partition presentation and review-before-apply workflow.
The KDE handbook available at that URL documents an older release; it is used
for interaction concepts, not current API or filesystem capability claims.
Future partition execution should use a reviewed native library/tool integration
and narrow Polkit authorization, not generated shell strings from UI requests.

For the first alongside path:

1. Inspect firmware mode, target identity, existing layouts and real OS/EFI boot
   data. Check disk health, backups, encryption and Windows shutdown state.
2. Ask the user to prepare Windows space in Windows when needed. Microsoft's
   [Disk Management instructions](https://learn.microsoft.com/en-us/windows-server/storage/disk-management/shrink-a-basic-volume)
   describe shrinking into unallocated space. Free bytes inside C: are not a
   contiguous unallocated partition extent.
3. Keep recovery material available and handle encryption explicitly. See
   [Microsoft's BitLocker guidance](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/faq).
   Do not request or log recovery keys in this preparation UI.
4. Require a verified GPT/UEFI layout and at least 32 GiB of contiguous
   unallocated space for this initial planning path. Preserve Windows/data,
   Microsoft reserved and recovery partitions. Reuse a verified ESP without
   formatting; verify its free space and preserve Windows Boot Manager files.
5. Show an exact before/after layout, every mount point and format flag, software
   selection, downloads and boot changes. Obtain disk-specific final consent.
6. Only then execute, install the independent minimal rootfs plus selected
   groups, configure the user and bootloader, and verify both OS boot paths.

The Arch dual-boot page was also requested during research but access was
blocked by its web protection; it is not cited as evidence for unverified facts.

## Execution roadmap and acceptance gates

| Stage | Required work before enabling it |
| --- | --- |
| Read-only explorer | Delivered; add hotplug-driven refresh, filesystem usage and health details without a polling daemon. Physical disks and removable drives still need hardware checks. |
| Partition execution | A queued operation model, explicit pending changes, per-filesystem capability/health checks, active holders/RAID/LVM/swap checks, cancellation and failure handling, Polkit broker and final target revalidation. |
| Dedicated-disk GUI install | Bridge to the minimal target payload, user/region/encryption/boot steps, package audit and offline core matrix. Do not reuse the erase-only CLI for alongside mode. |
| Dual boot | Disposable Windows-like GPT fixtures first, then a licensed Windows VM; compare protected partition content/geometry/EFI files before and after. Verify both OS boots. No physical Windows disk experiments before this gate. |
| Manual install | Root/ESP/shared-data assignment, explicit format decisions, filesystem support matrix and invalid-layout prevention. |
| Release | Zero/Git/Node/Python choices, offline install, cancellation, interrupted operations, full disks, hotplug, failed authentication and recovery. Installed-core RAM gate remains mandatory. |

The future executor must **not** treat this UI proposal as authorization or a
validated command sequence. It must independently validate the current target,
privileges, filesystem state and final consent. Logging must redact secrets and
avoid recording personal disk identities outside the explicit review UI.

## Executed verification

- Arch Live: **90 tests passed**, `Ran 90 tests in 1.635s`, `OK`. Twelve new
  fixture tests cover GPT gaps, 4Kn/START units, overlaps, whole-device filesystems,
  duplicate identities, missing/stale targets, protected/mounted/encrypted
  partitions, running-system disks, contiguous-space requirements, selection
  policy and malformed requests. They never touch real block devices.
- Windows Check: **exit 0**, 90 tests in 2.379s; **53 passed / 37 Linux-only
  skips**, plus shell syntax and pipeline-plan checks.
- Builder ShellCheck **0.11.0**: no findings for `scripts/*.sh` and the native
  Settings feedback regression wrapper.
- Actual Glass VM: Storage explorer and Install Forynarch entry open. Method →
  Software → Review succeeds with no optional groups selected. The current VM
  reports a roughly 22.75 GB blank virtual disk and **legacy boot**; the proposal
  correctly reports missing UEFI/GPT/ESP/contiguous space and remains non-executable.
- No partitions were created, deleted, resized, formatted, mounted or unmounted;
  no user account, EFI entry or package installation was changed for this task.
- After closing Settings, six Live memory samples five seconds apart peaked at
  **1,421,119,488 bytes** (1.42 GB decimal), swap 0; collector exit 0 against
  **3,000,000,000 bytes**. Existing applications were retained. This is a short
  Live snapshot, not installed-core idle acceptance or a performance comparison.
- Physical disks, BitLocker unlocking, NTFS resizing, real Windows boot detection,
  actual dual-boot installation and interrupted-operation recovery remain untested.

Screenshots and logs are ignored under `out/virtualbox/`. The previously built
ISO is unchanged. Next smallest step is a separately approved disposable UEFI
test VM with a suitable virtual disk and a pinned Calamares/backend integration;
not enabling writes on the current VM or on the Windows host.
