# Blue Hour R5.4.1 review — 18 October 2026

## Intent and changed areas

Repair wallpaper selection, Bluetooth recovery and compact audio controls;
add independent application playback/capture device choices; suppress Hyprland
update news and refresh stable Arch packages during approved ISO builds.
Integrate the requested Particle Circle GRUB theme. Earlier work in this
candidate also improves widget contrast, fixes window-button order, makes the
About identity explicit and adds experimental VM network/audio switches and
BitLocker guidance. All shipped interface text remains English.

Relevant sources:

- `scripts/forynarch-wallpaper.py`, `config/Thunar/uca.xml`, the wallpaper user
  service and `scripts/forynarch-desktop-integrate.sh` provide a cached wallpaper
  selection, login restoration and one functional File Manager action.
- `scripts/forynarch-audio.py`, `AudioRouter.qml`, `AudioAppRoutes.qml`,
  `AudioOutputs.qml` and both Control Center styles provide compact audio
  controls. Output/input routes are independent. System default follows the
  global device; App settings removes Forynarch's routing override.
- Bluetooth Settings checks BlueZ/rfkill, reports rejected discovery and offers
  a narrowly scoped authenticated recovery action. Only the local active Live
  user receives the existing Live authorization exception.
- `config/hypr/identity.lua` sets `ecosystem.no_update_news`. It does not hide
  compositor configuration errors. See the [upstream option](https://wiki.hypr.land/configuring/core/config-options/).
- `scripts/forynarch.sh` runs a full builder `pacman -Syu` during approved builds,
  then resolves fresh target/Live roots. Version/API gates remain enforced.
- `scripts/grub_theme.py`, `config/grub/`, `assets/grub/` and the dedicated-disk
  installer integrate the [Particle Circle theme](grub-particle-circle.md),
  preserving its license and source provenance. UEFI Live uses GRUB; the BIOS
  Live fallback remains Syslinux. The dedicated UEFI target uses GRUB's
  removable path without writing firmware NVRAM.

## Versions and assumptions

The fresh target contains GRUB `2:2.16-1`, Hyprland `0.56.2-4`, Quickshell
`0.3.2-1`, BlueZ `5.87-2`, WirePlumber `0.5.18-1` and PipeWire `1:1.6.9-1`.
Builder Archiso is `91-1`. Native tests use disposable VirtualBox Live sessions;
personal disks and firmware entries were not opened for writes.

Candidate ISO: `forynarch-2026.10.18-blue-hour-r5.4.1.iso`, **3,755,556,864 bytes**.
SHA-256:
`662c66b5311188546b7e12f3153f937368c44290f5bd5166cd1c40f6c9ff54c2`.
The Windows copy matched the builder checksum. Generated ISO/VM files remain
ignored by Git.

Git, Node.js, npm and developer toolchains remain opt-in. Python is not an
explicit core selection; the existing documented runtime dependency exceptions
remain. Mudil Music stays an unchecked optional package, with its package hash
verified in the installer payload. About exposes Forynarch and Muhammad
Muzammil Fadhil as fixed interface labels; an open-source fork can still edit
the source.

## Verification

- Arch source suite: **263 tests run, 261 passed, 2 skipped** (`15.048s`).
  The skipped tests require development-only Node and native Zsh on the builder.
  Tests cover stale audio-stream rejection, direction/device validation,
  independent routes, wallpaper failure rollback, Bluetooth health, GRUB
  staging and the diverted XFCE wallpaper extension.
- ShellCheck with sourced-file following passed for the build, window-control,
  File Manager and desktop-integration scripts. `grub-script-check` accepted
  the generated Live configuration; the diagnostic generator passed Bash
  syntax checking. `git diff --check` passed, with line-ending warnings only.
- Native wallpaper selection passed through an actual File Manager context-menu
  click. Only one Set as wallpaper action remained after restarting File
  Manager. A file URI containing spaces worked; the cached image survived
  deletion of its original and renderer restart.
- Native PipeWire fixtures passed independent playback/capture links, switching
  the system default while a stream remained open, and restoring App settings
  without changing the other direction. Fixture devices/streams were removed
  and original defaults restored afterward.
- Both classic and MacShell audio panels rendered directly without opening
  Settings. The classic panel rendered per-application input/output selectors.
  Quickshell loaded without QML errors; VirtualBox's missing render device used
  its expected shared-memory fallback.
- Native connectivity fixtures passed scanning, device sorting, password
  isolation, advanced routing, Bluetooth pairing confirmation and scan cleanup.
  VirtualBox reported no Bluetooth radio; this is not a physical pairing test.
- The ISO booted its actual Particle Circle UEFI menu and continued to the
  animated Forynarch Plymouth screen. Final cold desktop boot matched **128 source
  files**, loaded the window-control plugin without Hyprland config errors,
  enabled update-news suppression and verified every bundled checksum. The
  explicit core included GRUB and excluded browsers, Mudil and developer tools.
  Native connectivity and independent audio-route fixtures passed again on the
  cold ISO.
- Five final Live samples peaked at **1,488,998,400 used bytes**, swap **0**,
  on a 3 GB/two-CPU VirtualBox VM at 1920×1080 after glass/audio QA, with the
  Control Center closed. This is not an installed-target memory certification.
- A new **32 GiB disposable VDI** passed offline installation with zero optional
  groups. The test checked its VM identity, exact disk serial/size and blank
  filesystem state, reviewed the plan, and supplied the disk-specific fixture
  consent through the normal graphical consent transport. The installed package
  inventory matched the reviewed transaction. GRUB EFI installation and config
  checking passed. With the DVD removed, the disk displayed the requested theme,
  booted Kath SDDM and signed the passwordless fixture account into Hyprland.
  The glass correction was then applied to that fixture's skeleton/home from
  the same three QML files and compiled liquid shader shipped in R5.4.1;
  the installer code and package set were unchanged.
- The installed core then passed a new five-minute idle run followed by **six
  samples at ten-second intervals**: peak used RAM **1,354,928,128 bytes**,
  swap **0**. Measurement used `MemTotal - MemAvailable` on the 3 GB/two-CPU
  VirtualBox fixture at 1920×1080, with no application windows open. The temporary
  Python QA monitor was included in that total and removed afterward. All
  checks passed for desktop login, valid Hyprland config, GRUB fallback/theme,
  absence of Live authorization and no default browser/developer tools.
  Offline inspection matched **126 installed source/shader files** to the final
  manifest; the Live-only installer and authorization rule were excluded.

## UI delivery gates

The first R5.4 candidate exposed a MacShell packaging bug: the shader compiler
produced `liquid.frag.qsb`, but the fresh build copied only the glass and motion
shaders. R5.4.1 copies all three into the core skeleton and Live profile.
MacShell cards and its single-panel mode also retain their base background
underneath the effect, so a missing/unrendered shader cannot make controls
float directly on the wallpaper. Software rendering disables the shader loader;
Qt documents that its [software backend does not render ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html).

`tests/run-control-glass-flow.sh` passed with both the Qt software backend and
OpenGL/llvmpipe with the actual compiled shader. It verifies a readable base,
unsupported-backend handling, shader failure and disabled glass. An additional
OpenGL run with the shader absent passed the fallback checks. The complete
Control Center rendered its actual glass cards in the native desktop after the
compiled shader was installed. No new background service is used for this fix.

- **Purpose / hard constraints: PASS for the tested scope.** Wallpaper has one
  working action; the speaker opens audio; device choices are directional;
  authenticated recovery is separate from read-only discovery.
- **Craft: PASS for inspected surfaces.** Classic and MacShell panels retain
  their respective styling; widget surfaces share the navy palette. Native
  screenshots cover the audio panels, context menu and actual GRUB menu.
- **Motion: PASS for existing behavior.** Panel transitions and boot animation
  remain; no new always-running routing/animation daemon was added. The
  wallpaper launcher replaces itself with swaybg. Audio discovery polls only
  while its UI is open. GRUB artwork is static boot-time graphics.
- **Accessibility: PASS for checked text/states.** Device choices have labels
  and error states; widget muted text on the brightest clock surface measures
  5.06:1, and chip text measures 9.85:1. This does not certify every translucent
  pixel or every third-party application.

## Storage retention

The requested cleanup removed 18 unused ISO files and obsolete Linux build
outputs, then returned free ext4 blocks through VirtualBox discard. It reclaimed
approximately **153.9 GB decimal** before this fresh build. VM-referenced ISO
files, personal VM disks, source, credentials and optional payloads were kept.
The builder now has discard and periodic trim enabled. The checked-in cleanup
script defaults to a dry run and protects VM references; see
[artifact retention](build-artifact-retention.md).

After the fresh GRUB build replaced the old cache, a second guarded cleanup
removed **31,098,572,800 allocated bytes** of obsolete prepared roots, the old
Archiso work tree and duplicated builder artifacts. It retained the host ISO
releases and all VM references. Windows had approximately **167 GB decimal**
free after the new ISO and disposable install disk were created.

## Remaining verification

Physical Bluetooth pairing and GPU/power behavior remain untested. Live RAM must
be reported separately from the installed-core requirement of less than
3,000,000,000 bytes. The zero-extra dedicated-disk path passed on the fixture;
the complete selective/offline/cancellation installer matrix was not repeated
for this candidate. Secure Boot, shared-ESP migration and automatic alongside
installation are not implemented by this change.

Mudil's real application registered MPRIS and opened its onboarding/home in a
disposable Live test. A native MPRIS fixture verified artwork and lyric display;
actual online Mudil playback with lyrics was not certified. Existing-OS VM
tests used disposable block fixtures, not an actual BitLocker Windows system.
The guest can require the owner's recovery key after a TPM/hardware change;
Forynarch does not bypass encryption. See
[existing OS and BitLocker](wiki/existing-os-and-bitlocker.md).
