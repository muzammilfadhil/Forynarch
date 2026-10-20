# Installer correction: R5.7

The installer executes dedicated-disk and prepared-root/EFI installations. Its
Live UI identifies itself as an installer; read-only review before confirmation
is retained. The preview-only product label and obsolete blanket installation
blocker have been removed.

## Findings and changes

- `storage-inventory.jq` required 1 MiB padding after every partition, including
  the last one. Valid GPT disks with a recovery or Linux partition ending at
  the last usable sector therefore failed `geometryKnown`. The inventory now
  separates GPT type from boundary validation and uses the logical sector size
  for standard GPT metadata reservations. Actual writes additionally require
  the util-linux partition-table integrity check and stable geometry.
- Live discovery and privileged execution previously could read different
  metadata when udev lacked a table or filesystem property. Live now performs
  the same direct, read-only block metadata probe with its existing passwordless
  policy. The installed desktop does not gain a new sudo rule.
- Alongside review still demanded 32 GiB of unallocated space after the root
  partition had already been prepared. Root/ESP assignment validation now owns
  that decision; it does not require a second unused region.
- UEFI/Legacy mode is displayed independently from GPT. Mounted volumes, protected
  disks, missing identities, Secure Boot and unsupported layouts have early,
  specific messages. Public preflight blockers survive execution revalidation.
- Intel/AMD Vulkan choices previously could be selected but always blocked the
  final review. They now reach the signed optional package transaction, with a
  fixed package allowlist and repeated hardware/offline checks. Other unverified
  driver choices remain disabled with an explanation.
- An existing Forynarch EFI loader previously prevented reinstalling. Its files
  are now backed up before replacement. Other OS loaders are preserved and
  Forynarch backups are excluded from generated OS boot entries.

The main affected files are the storage inventory/planner, `install_layout.py`,
`install-target.sh`, installer info/review/transport helpers, `InstallerModel.js`,
`shell.qml`, `WelcomePanel.qml`, the driver catalogue and build integration.

## Verification

Targeted installer and partition regressions run in the Arch builder. Native UI
and disposable reinstall results are recorded after image assembly. No personal
disk is a development target. The relevant environment is Quickshell 0.3.2,
Qt 6.12 and util-linux 2.42.4.

- Installer regression discovery: **34 tests passed** in 0.693 seconds.
- Partition preparation discovery: **12 tests passed** in 0.241 seconds.
- ShellCheck on the changed shell entry points: exit **0**, no diagnostics.
- Native Wayland QML fixtures: exit **0** for both setup navigation/validation
  and the fake-executor confirmation/private-input/progress/completion flow.
  Only the test process is substituted; the source QML and its compiled welcome
  shader run on Qt. These fixtures do not perform real disk writes.
- Initial installation-acceptance image: `mkarchiso` exit **0**. The copy is **3,839,197,184 bytes**;
  SHA-256 matches the builder:
  `e9306064d758f35a24ff8fbf40c1448f02c7a9217d30dab97855ae543d17361a`.
  Artifact: `forynarch-2026.10.18-blue-hour-r5.7.iso`.
- Real offline reinstall on the existing 64 GiB disposable UEFI fixture:
  installation transport exit **0**, **573** core packages. The complete GPT
  snapshot and 2 GiB NTFS digest remain identical; other EFI files are retained,
  the previous Forynarch loader is backed up, and firmware entries are unchanged
  with registration unchecked. Windows and Ubuntu chainloader paths remain in
  GRUB. No default developer packages or Live sudo rule leak into the target.
  The harness initially expected an old Ubuntu menu title; correcting that
  assertion to check the EFI loader path completed the remaining read-only
  checks without reinstalling again.
- UEFI boot after reinstall reaches the installed Kath SDDM login, and signing
  in reaches the installed Hyprland desktop as `forynarchqa`. The original
  fixture VM's frontend subsequently aborted before powering on; an independent
  VM configuration booted a clone of the installed fixture successfully. The
  original disk and restored firmware BootOrder remain intact. This isolates
  that startup failure from the installed boot files rather than claiming the
  Windows/VirtualBox issue is repaired.
- Final media refresh updates only Live documentation and the stale CLI banner.
  The complete installer/helper/payload checksum manifest remains unchanged.
  Published ISO SHA-256:
  `7f694549d178cd4cb376e9c225fde167141fb353a296f70dfe1cf216c8ea66cd`.

The source tests include a real sparse GPT file whose Linux partition reaches
the last usable sector, synthetic 512-byte/4Kn and first-usable-sector layouts,
stale/mounted/protected targets, offline and wrong-vendor driver rejection,
optional-package isolation and preservation of every safety blocker.

## Scope and remaining acceptance

Prepared root and EFI assignments are on the same disk. KDE Partition Manager
performs partition preparation with its own review. Automatic shrinking, encrypted
Linux installation, legacy BIOS boot and Secure Boot signing are not implemented.
Physical firmware and proprietary GPU acceptance remain separate from a working
installer. The previous installed-core idle measurement is historical evidence;
this correction does not add an idle daemon or claim a new memory benchmark.
Vulkan selection validation and argument/transaction integration are covered;
an actual Intel/AMD GPU installation is not exercised by the VirtualBox adapter.

## Interface delivery review

The owner's navy desktop and nine-stage installer reference remain the direction.
ENERGY 2 / RHYTHM 2 / MOTION 3 is unchanged. Motion is a finite arrival, disabled
by Reduce motion; no persistent animation or new idle timer was added.

Hard Gate PASS: native fixtures cover all page Loaders, Back retention, account
errors, offline reset, Cancel focus, private input and real Process completion;
the substituted executor cannot target a block device. There is no dead Install
action on an otherwise valid supported plan.

Purpose-Gate PASS: the fixed footer keeps navigation outside the storage scroll
area; the warning text explains the condition that blocks installation; the
confirmation names the actual destructive target. Existing navy styling retains
the owner's direction rather than introducing another visual theme.

Liveliness PASS: the finite shader arrival compiles, settles and responds to
Reduce motion in the native fixture. No idle animation is introduced.

Craft/accessibility PASS: keyboard/modal focus and page layout checks pass. The
new error foreground `#ffc2af` on `#101c2d` measures **11.08:1** with the skill's
contrast checker. Original labels and warning semantics remain available at
the supported desktop window size; no new mouse-only control is introduced.

References: [UEFI GPT format](https://uefi.org/specs/UEFI/2.11/05_GUID_Partition_Table_Format.html),
[lsblk metadata probing](https://man.archlinux.org/man/lsblk.8.en),
[sfdisk integrity checking](https://man.archlinux.org/man/sfdisk.8.en).
