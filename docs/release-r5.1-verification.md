# Blue Hour R5.1 verification

Date: 17 October 2026. This release contains independent bar/Control Center
styles, the MacShell tile layout and neutral glass material, matching advanced
audio controls, configurable panel geometry, and window-preview actions.

See [implementation and UI review](panel-control-center-review.md),
[user guide](wiki/screenshots-clipboard-and-media.md), and
[upstream credit](../config/quickshell/forynarch/MACSHELL-SOURCES.md).

## Artifact

- File: `out/iso/forynarch-2026.10.17-blue-hour-r5.1.iso`
- Size: **3,979,575,296 bytes**
- SHA-256: `0aba19a7954b18928416032083409a0c7936cae331025b6333f72378bcd46757`
- Built by `mkarchiso` on the Arch builder's Linux-native scratch filesystem.
  Qt shader compiler version: **6.12.0**.

## Build validation

The final source passed **241 Python tests, 2 skipped** on Arch. Native QML
packing and preference validation passed. All shader bundles compiled. The
target and Live filesystem audit confirmed source integration, bundle checksums,
the installer's package database layout, and the unchecked optional Mudil Music
package with its expected SHA-256. Core checks exclude Git, Node.js, npm,
compiler toolchains, Mudil Music and mpv from automatic installation. The ISO
checksum verified on the builder.

## Windows copy and cold boot

The Windows copy matches the SHA-256 above and has a matching `.iso.sha256`
sidecar. The diskless `Forynarch-R48-Review` VM booted this exact ISO with
3 GB RAM and two CPUs. Installed release packages are Hyprland **0.56.2-4**
and Quickshell **0.3.2-1**.

Cold checks passed all **90** QML/JS/fragment source hashes, the seven-module
Fastfetch configuration, shader bundle presence, optional Mudil package checksum
and unchecked installer choice, zsh login shell, core package exclusions,
screenshot defaults and disabled clipboard history. Hyprland reported no config
errors. Factory appearance remained Forynarch; lyrics and Cava were inactive.
Default monitor reservation was 52 px. Switching only the Control Center to
MacShell on the cold ISO produced a captured, ready Liquid Glass surface with
`failed=false` and preserved the Forynarch bar.

Five Live measurements, two seconds apart, used `MemTotal - MemAvailable`:
**1,326,301,184; 1,326,297,088; 1,260,785,664; 1,255,104,512;
1,260,367,872 bytes**. Peak was **1,326,301,184 bytes** (1.33 GB decimal);
swap used was **0 bytes** throughout. This is a cold Live VM snapshot, not an
installed-core memory certification. A fresh installed target on physical
hardware still needs the project's below-3-GB gate.
