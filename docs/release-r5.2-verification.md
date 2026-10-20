# Blue Hour R5.2 verification

Date: 17 October 2026. The release implements native minimization, explicit
fullscreen actions, separate audio and Control Center buttons, mode-aware cursor
focus, configurable outlines, blue Control Center glass, MacShell music/lyrics,
local emoji-font import and aligned Fastfetch output.

## Artifact

- `out/iso/forynarch-2026.10.17-blue-hour-r5.2.iso`
- **3,979,575,296 bytes**
- SHA-256: `5fcad5f39780b804938e79feaa4ee478bac547c96b3c570fdc934de8f12ede65`
- Matching `.iso.sha256` sidecar on Windows.

The ISO was built with `mkarchiso` on the Arch builder's Linux-native scratch
filesystem. The Windows copy matches the builder checksum. The target/live audit
passed source integration, native extension/model/helper comparisons, installer
database layout, optional Mudil package review, bundle checksums and ISO integrity.
Developer toolchains and optional Mudil/mpv remain excluded from automatic core
installation. Builder-only native compilation did not add target packages.

## Source and native verification

- Arch Python suite: **246 tests, 244 passed, 2 skipped**.
- Quickshell layout fixture: **PASS**, 100 packing permutations and twenty
  preference boundaries.
- Native focus fixture: **PASS** for tiled centering, floating focus and the
  actual Alt+Tab helper preserving pointer coordinates.
- Actual Firefox minimize button, fullscreen picker, fullscreen exit, desktop
  hide/restore, minimize and Alt+Tab restore: verified as described in
  [the implementation review](desktop-controls-r5.2-review.md).
- All shader bundles compiled with Qt **6.12.0**. Blue fallback contrast:
  secondary `#c5c5c9` on `#16283e` **8.67:1**. Actual translucency depends on
  background content and the user's settings.
- Importer validated a local Noto font and installed it in the user's font
  directory. Apple font binaries were neither supplied nor redistributed.

## Exact ISO cold boot

The diskless `Forynarch-Desktop-Controls-QA` VM cold-booted this ISO with 3 GB RAM,
two CPUs, VMSVGA and USB tablet input. **97** source/binary checksums matched,
including the compiled native extension. Hyprland reported no config errors, and
the extension loaded automatically on **Hyprland 0.56.2-4**. Quickshell is
**0.3.2-1**. Fastfetch has the requested seven modules and no side logo. The
installer's optional Mudil choice remained available and unchecked.

Factory bar style is Forynarch, music style is MacShell, and lyrics, Cava and
clipboard history are off. Default panel reservation is 52 px. The Live Welcome
screen appeared; selecting Try Forynarch entered the desktop. The QA profile was
then set to the MacShell Control Center for visual review. USB tablet absolute
input reported the requested coordinates; the earlier PS/2 injection limitation
did not affect the packaged source or the relative-motion focus checks.

Five cold Live snapshots, two seconds apart, measured `MemTotal - MemAvailable`:
**1,245,274,112; 1,245,274,112; 1,242,845,184; 1,231,728,640;
1,229,574,144 bytes**. Peak was **1,245,274,112 bytes** (1.25 GB decimal), with
**0 bytes of swap used** throughout. This snapshot includes first-session Live
UI and is not an installed-target benchmark. The installed-core below-3-GB gate
still needs a physical installed-system measurement.

See [window controls and shortcuts](wiki/window-controls.md),
[font documentation](widgets-and-emoji.md), and
[MacShell source credit](../config/quickshell/forynarch/MACSHELL-SOURCES.md).
