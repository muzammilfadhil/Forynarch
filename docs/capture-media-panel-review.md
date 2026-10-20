# Capture, media and floating desktop verification

Implemented on 17 October 2026. The feature guide is
[Screenshots, clipboard and music](wiki/screenshots-clipboard-and-media.md).

## Changes

- Screenshot application, Print Screen and Super + Shift + S, configurable
  destinations and clipboard-only capture.
- Opt-in bounded clipboard history with copy, deletion and complete clearing.
  Super + Ctrl + V opens it; Super + V retains float/tile.
- Optional MacShell panel and Control Center with a one-frame Liquid Glass
  shader; classic panel remains the default. The player port retains its MIT
  license, uses navy surfaces and actual compositor blur.
- Configurable music player, artwork, lyrics and classic-card Cava visualizer.
  Lyrics and history are off by default. Cava runs only when its card is visible,
  playback is active and motion is enabled.
- Mudil Music Linux MPRIS support and a separately bundled, unchecked installer
  selection. Native runtime dependencies are `mpv`, `libsecret` and GTK3.
  The installed core excludes the application and developer toolchains.
- Super + H minimizes. Alt + Tab and the application bar restore minimized
  windows on their originating workspace, preserving floating dimensions.

## Verification

The Arch builder suite ran 241 tests: OK, 2 skipped. The disposable Live VM suite
ran the same 241 tests: OK, 1 skipped. These include bounded clipboard storage,
selection/manifest validation, lyric parsing and minimized-window routing.

Native Wayland checks verified fullscreen PNG copying, clipboard-only capture,
history copying/deleting/clearing, pointer-drag region capture and Escape
cancellation. Cancellation preserved both files and the clipboard.

Floating fixtures passed minimize/Alt+Tab/activation restoration with unchanged
dimensions. Actual keyboard input also minimized Mudil Music with Super + H,
restored it with Alt + Tab, and restored it through a pointer click on the bar.

MacShell Control Center reported a captured frame and an available shader with
no shader error. The menu bar reserved 32 pixels; classic layout retains its own
reservation. The music protocol fixture displayed artwork and three lyric lines.
It is a fixture, not evidence of real music streaming.

Mudil Music 3.9.0-2 was built using Linux Flutter 3.47.6/Dart 3.13.5 and
`audio_service_mpris` 0.2.1. It installed and opened in the disposable Live VM,
initialized storage and registered as **Mudil Music** on MPRIS. Flutter analysis
reported one existing informational Supabase `anonKey` deprecation, no errors.
An existing missing-Documents-directory case now falls back to application
support storage on Linux. Existing Documents stores keep their location.

The earlier R4.9 candidate exposed an old precreated Live Fastfetch config.
Factory migration and the revised repack now cover that home. Repacking also
preserves the installer package database's expected `local/` and `sync/` layout.

## Limits

Online lyric coverage depends on the track and service; real account streaming,
Bluetooth audio and physical GPU effects still need hardware/user-account QA.
No personal account or disk was opened. Final cold-boot artifact evidence is
recorded separately with the ISO checksum. Live memory readings do not establish
the installed-system memory gate; a fresh installed benchmark remains required.

Windows has an existing widget-pack drive-letter path test limitation; Linux
suite results above are the authoritative checks for that case.
