# Connectivity, Live memory and Kath login review

Update: the owner subsequently selected video as the Kath default. See the
[video verification record](kath-video-review.md); static-default and static-only
resource figures below describe the earlier revision.

15 October 2026. Source and disposable Live previews only; no new ISO was built.

## Changes

Network and Bluetooth settings now start with nearby devices, radio controls,
connection state and finite discovery. Wi-Fi passwords use a masked graphical
prompt and are passed directly to NetworkManager through Quickshell. Advanced
network editing remains a secondary action. Bluetooth device options contain
trust and a confirmed Forget action. Scans stop when the page closes or its
radio is switched off. All shipped copy is English.

The Bluetooth pairing agent is an on-demand Qt Core/DBus executable, with no
resident daemon or Python runtime. Its source is prepared, but compilation and
backend verification are pending approval to install gcc/make in the builder.
The Live preview disables new-device pairing when that executable is absent;
UI tests use a scoped fake helper. Real pairing is not yet validated.

The installed target is configured to use SDDM with a local adaptation of
[Keyitdev's Hyprland Kath theme](https://github.com/Keyitdev/sddm-astronaut-theme).
See [theme provenance](../config/sddm/themes/forynarch-kath/UPSTREAM.md) for the
pinned revision and retained license. The four actions are Shut down, Sleep,
Hibernate and Restart. Each checks SDDM capability, asks for confirmation with
Cancel focused, and checks capability again before invoking its SDDM method.
Unavailable actions remain visible but disabled. Hibernate needs actual system
support; displaying a button does not configure swap or resume.

The default background is the upstream static Kath frame, with bounded local
blur and a horizontal alpha fade into the artwork. Static blur is cached at
half resolution; the login form has a finite arrival animation and a
ReduceMotion setting. Default loading avoids Qt Multimedia and the virtual
keyboard. The optional video is retained but was not tested. SDDM and qt6-svg
are target packages; no developer SDK is added to the target. SDDM is not
enabled in the Live session, which retains its desktop startup behavior.

## Live USB memory

The installed mkinitcpio-archiso 73-1 hook defaults to automatic copy-to-RAM.
For a suitable non-optical device, a compressed image below 4 GiB and enough
available memory can trigger copying. An ISO mounted as a VM CD-ROM follows a
different path. See the [official hook](https://github.com/archlinux/mkinitcpio-archiso/blob/master/hooks/archiso).
[Ventoy Memdisk](https://www.ventoy.net/en/doc_memdisk.html) separately loads an
entire image into memory. Therefore Ventoy alone does not establish why a
particular laptop shows 5 GB used.

New staged local boot entries explicitly use `copytoram=n`, while preserving
explicit existing choices and leaving network boot entries alone. This policy
was exercised against Archiso 91's actual releng profile: eight entries in five
files changed; a second pass changed zero files. For the existing USB, use
Ventoy Normal mode and add `copytoram=n` to the Linux boot command line. Keep
the USB attached. The existing ISO has not acquired this source change.

`forynarch-live-diagnostics` reports memory bytes, swap and an actual
`/run/archiso/copytoram` mount, without dumping raw command lines or network
identifiers. The user's laptop still needs diagnosis; `/proc/cmdline` and
`free -b` were requested. Do not add shared/cache/copy figures together: their
accounting can overlap. Acceptance remains installed-core
`MemTotal - MemAvailable < 3,000,000,000 bytes`, with swap recorded separately.

## Verification and delivery gates

Versions inspected: Quickshell 0.3.2-1, Qt 6.12.0, NetworkManager 1.58.1-2,
BlueZ 5.87-2, SDDM 0.21.0-7 and Archiso 91-1. Build integration stops for review
if SDDM leaves the reviewed 0.21.0 release. Native networking API reference:
[Quickshell 0.3.2](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/).

- PASS: Arch builder Python suite, **104 tests**, **1.716 s**, no skips, exit 0.
- PASS: Windows suite, **104 tests**, **2.340 s**, 48 Linux-only skips, exit 0.
- PASS: all shell source and test runners parse; ShellCheck has no findings.
- PASS: native connectivity fixture covers discovery lifecycle, ordering,
  password isolation, advanced routing, pairing confirmation and cleanup.
- PASS: native power fixture verifies all four mappings, unsupported actions,
  confirmation focus, cancellation and capability changes using inert methods.
- PASS: native settings fixture hides successful CLI `ok` output and retains errors.
- PASS: actual SDDM greeter test-mode preview renders Kath with no overlap at
  1280 x 800. Its package signature was verified against the Arch keyring before
  extraction into `/tmp`; no package/service/account installation was performed.
  Preview-only copy disables sign-in and power and displays that fact. Source
  configuration keeps real SDDM authentication enabled. No credentials were tested.
- PASS: owner-selected artwork, navy palette, readable controls, bounded motion,
  cancellation and finite scan states are represented in the actual QML preview.
- PENDING: C++ pairing compilation/backend tests and physical Wi-Fi/Bluetooth.
- PENDING: real PAM sign-in, greeter exit/restart lifecycle, power/resume,
  optional video, multiple resolutions and installed-target RAM acceptance.
- PENDING: a rebuilt ISO and fresh target installation. The builder has only
  about 4.4 GB free; existing build outputs were not deleted.
- PENDING: independent background redistribution-rights review before publication.

The portable greeter preview runs alongside the existing Live desktop and uses
software rendering. It is a UI check, not a measurement of an installed SDDM
login lifecycle or physical GPU behavior. No host disks, EFI data, accounts or
Windows security settings were changed.

After startup, six samples five seconds apart peaked at **1,273,245,696 bytes**
used (`MemTotal - MemAvailable`), with **0 bytes swap**. Greeter RSS was
**251,043,840 bytes**; its CPU delta was **0.04% of one core over 25 seconds**.
The entire Live desktop remained running during collection. The preview copy
disabled form input and used a static background, so this does not establish
resource use during authentication or video playback. Screenshot evidence:
`out/virtualbox/kath-preview-final.png` (generated, intentionally not tracked).
