# R5.9.0 release candidate

Creator: **Muhammad Muzammil Fadhil**. Base: Arch Linux. Desktop: Hyprland.

This full-image candidate incorporates the installed-system fixes through
R5.8.8. Native floating titlebars retain application-owned decorations for
normal Chrome, Discord and Mudil Music; frameless web apps retain external
controls. Settings includes editable application exceptions. The native
titlebar damage fix clears both previous and current decoration bounds.

The image also includes the existing installer transaction/logging fixes,
configurable panel and battery details, network speed test, audio controls,
widgets, screenshot/clipboard tools and optional software selection. Developer
tools remain opt-in. Existing-OS virtualization remains experimental and
disabled by default.

Public-distribution changes use original Forynarch navy artwork at login and
lock. Unverified Kath media and the separately licensed Mudil Music application
binary are omitted. Player integration remains included. Upstream theme code,
notices, font source and font-specific OFL notice are retained.

## Verification

Full image: `forynarch-2026.10.20-blue-hour-r5.9.0.iso`.
Size: **3,833,626,624 bytes**.

SHA-256:

```text
148f9bcdd45028f0feb7de9929c39b970f03faec052a5621571711a40290d228
```

- Arch build: full stable builder update; 336 build-time unit tests completed
  with 2 skipped. After adding the final export naming regression test, the
  source suite completed 337 tests with 335 passed and 2 skipped. Hotkey checks, Bash syntax and ShellCheck passed.
- Windows: 337 unit tests completed, 184 passed and 153 native-only checks
  skipped. The public-source exporter additionally verifies exclusion of
  ignored tracked files, preservation of existing destinations and source hashes.
- Built versions: Linux `7.2.11.arch1-1`, Hyprland `0.56.2-4`, Quickshell
  `0.3.2-1`, SDDM `0.21.0-7`. The completed Live package database matches
  both compiled native extensions.
- Fixed a build-only regression where titlebar version validation queried the
  unpopulated Live package database. Template fallback is restricted to an
  unpopulated Live staging root; actual versions are checked after mkarchiso.
  Target roots and mismatched populated roots are rejected by regression tests.
  The build continued from the completed target payload after those checks.
- SHA-256 was verified again after copying the image to Windows.
- Booted that image in a diskless VirtualBox UEFI VM, 2 vCPUs, 3,072 MiB RAM,
  VMSVGA, 1920 × 1080. Welcome appeared automatically. Hyprland reported no
  configuration errors; both native plugins loaded. The standalone installer
  opened to its welcome screen without disk changes. Logging out returned to
  the themed SDDM greeter, with public artwork and passwordless Live sign-in.
- About displayed the fixed creator identity and `Live session`. The optional
  Liquid Glass Control Center reported its capture and shader ready, with no
  failure. Floating terminal minimize/restore preserved position and size.
- Package inventories were exported: **575 target packages**, **779 Live
  packages**. Git, Node.js, npm, GCC and Docker are absent from the target.
  Python remains a documented runtime dependency, not an opted-in toolchain.
  See the exact package evidence supplied with the local release artifacts.
- [Eight actual guest screenshots](screenshots/README.md) are included.
- With all application windows closed, one Live VM snapshot measured
  `MemTotal - MemAvailable = 1,485,496,320 bytes`, total RAM 3,088,064,512 bytes,
  swap 0 bytes. `copytoram=n` was active. This is a Live measurement and does
  not satisfy the separate installed-target memory gate.

Earlier patch evidence remains in [R5.8.8 review](installed-patch-r5.8.8.md).
This candidate has not repeated a complete install-to-disk transaction or a new
installed-hardware idle-memory benchmark. Physical Wi-Fi/Bluetooth, GPU drivers,
multi-monitor behavior, BitLocker access and existing-OS virtualization require
their separate hardware/fixture checks; VM boot is not hardware certification.

## Publication gates

The owner must choose the original-code license. The clean public export must
pass the final source/secret review. Exact corresponding-source obligations
for distributed package binaries must be fulfilled before public ISO hosting.
See [publishing](publishing.md). This preparation does not publish online.

The [public-source review](public-source-review-r5.9.0.md) records the export,
ignored files, scanner scope and clean-history preparation.
