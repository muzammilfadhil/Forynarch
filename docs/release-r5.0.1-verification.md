# R5.0.1 build verification — 17 October 2026

## Artifact

Local output: `out/iso/forynarch-2026.10.17-blue-hour-r5.0.1.iso`

- Size: 3,977,281,536 bytes.
- SHA-256: `409c2ee87ca19c7ea765ce5e5a974fe59159d33181f807a7feb54305e15e9847`.
- The Windows copy matches the builder's checksum; a matching `.iso.sha256`
  sidecar is beside the image.

The R4.9 and R5.0 candidates are superseded by this artifact. The cached repack
now updates the storage helper, includes all three compiled shaders, migrates
the precreated Live Fastfetch configuration, and archives the installer package
database with its required `local/` and `sync/` layout.

## Scope and dependencies

Changes cover screenshot/clipboard helpers and QML pages, shortcuts, MPRIS/music
widgets, optional MacShell panel surfaces, minimized-window switching, installer
local-package validation, credits and wiki documentation. The feature guide is
[Screenshots, clipboard and music](wiki/screenshots-clipboard-and-media.md).

| Area | Main source files |
| --- | --- |
| Capture/history | `scripts/forynarch-capture.py`, `CaptureModel.qml`, `CapturePage.qml`, `CapturePanel.qml`, `ClipboardPanel.qml` |
| Music | `scripts/forynarch-media.py`, `MediaModel.qml`, `MediaWidget.qml`, `MusicSettings.qml`, `MacPlayer*.qml` |
| Panel/glass | `shell.qml`, `DesktopPanel.qml`, `MacControlCenter.qml`, `LiquidGlass.qml`, `shaders/liquid.frag` |
| Window switching | `scripts/forynarch-window-switcher.sh`, generated shortcut configuration |
| Installer | `scripts/local_applications.py`, `scripts/bundle-local-applications.py`, `scripts/install-target.sh`, `scripts/forynarch-storage.sh`, optional package manifests |
| Attribution | `README.md`, `docs/wiki/credits.md`, `licenses/MacShell-MIT.txt`, `MACSHELL-SOURCES.md` |

QML paths above are under `config/quickshell/forynarch/`.

Mudil Music source also received Linux MPRIS initialization, its dependency and
lockfile, a Linux storage-directory fallback, and corrected Arch runtime
dependencies. Its separate optional package is `mudilmusic` 3.9.0-2, SHA-256
`9f43634a4e54d305907a87da5682ab7fb1cb9cbac86fb1386f005caa393c9512`.
The package was compiled with Linux Flutter 3.47.6/Dart 3.13.5 and
`audio_service_mpris` 0.2.1. Qt 6 shader tooling compiled the adapted glass shader.
GTK3, libsecret and mpv are native Mudil runtime dependencies. No developer
toolchain or Mudil package was added to the installed core.

## Results

- Arch builder suite: **241 tests, OK, 2 skipped**.
- Disposable Live suite: **241 tests, OK, 1 skipped**.
- Shell syntax validation and scoped `git diff --check`: passed.
- Fullscreen PNG/clipboard-only capture, history copy/delete/clear and pointer
  region capture/cancellation: passed in Wayland. Escape preserved existing
  files and clipboard data.
- Real keyboard Print Screen on R5.0.1 created a PNG. Super + Shift + S started
  the region selector, and Escape cancelled it.
- Native floating fixtures retained dimensions through minimize and restoration.
  Super + H, Alt + Tab and a pointer click on the bar also worked with the actual
  Mudil application.
- Music protocol fixture: artwork and three lyric lines displayed; clicking the
  widget paused playback and advanced track metadata. This verifies the MPRIS
  protocol path, not real account streaming.
- Actual Mudil package: installed and opened in disposable Live QA, initialized
  storage and registered MPRIS identity **Mudil Music**. Flutter analysis had no
  errors and one existing informational Supabase deprecation.
- A public LRCLIB query returned `state: ok`, a timed lyric result and no error.
  No user account or private listening metadata was used in this check.
- Final staged-root audit: core package separation, bundled checksums, local
  package identity, installer database layout and optional repository dependency
  resolution passed. The Mudil choice is present, available and unchecked.
- Final ISO cold boot: source hashes matched capture/media/window/storage helpers,
  new QML components and seven-field Live Fastfetch configuration. No Hyprland
  configuration errors were reported. Live home ownership and shader presence
  passed. Default panel/music styles are classic; lyrics/history are off.
- MacShell Control Center: background captured, shader available, no shader error.
  The classic panel reserves 52 pixels and the MacShell panel 32. Persisted
  MacShell style was also checked after a shell restart.

## Memory snapshot and remaining verification

Final ISO, disposable VirtualBox Live session, 3 GB allocation, 2 vCPUs,
1280×800, default classic shell with the Welcome overlay dismissed. Five samples
at two-second intervals used `MemTotal - MemAvailable`:

| Sample | Used bytes | Swap used bytes |
| --- | ---: | ---: |
| 1 | 1,284,976,640 | 0 |
| 2 | 1,284,046,848 | 0 |
| 3 | 1,283,223,552 | 0 |
| 4 | 1,270,460,416 | 0 |
| 5 | 1,261,154,304 | 0 |

Peak was **1.285 GB decimal**. This is a Live snapshot, not an installed-target
benchmark and not proof that the installed memory gate has passed. Boot policy
keeps `copytoram=n`. Clipboard history has no watchers by default; Cava does not
run while idle or with the MacShell music card.

Remaining verification: a fresh installed-core idle benchmark, physical graphics
and Bluetooth/audio hardware, real-account streaming and track-specific lyric
coverage, and a complete installer execution on an explicitly reviewed
disposable target. No personal account, partition or EFI data was modified.
The next validation step is the installed-core memory protocol documented in
[Build and verify](wiki/build-and-test.md).
