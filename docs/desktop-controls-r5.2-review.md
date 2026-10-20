# Desktop controls R5.2 review

## Changes and dependencies

This update adds explicit fullscreen/maximize/minimize actions to Arrange Window,
native GTK/Firefox minimization, independent audio/Control Center buttons, a muted
blue Control Center without recording, configurable focus outlines, mode-aware
cursor behavior, the MacShell music view with lyrics, and user emoji font import.
Fastfetch's seven requested information rows now share one column.

See [the user guide](wiki/window-controls.md) and [font installation](widgets-and-emoji.md).
The new native extension is in `native/window-controls/`; its builder script uses
GCC/pkg-config and the exact installed Hyprland headers. These build tools are
not installed into the target. Integration checks the staged Hyprland package
version; the running extension checks Hyprland's full plugin ABI fingerprint.
It uses public Wayland resource iteration and Hyprland events, without a
compositor fork, private-field access, or a background polling service.

Shipped Linux strings remain English. New music profiles default to MacShell;
existing explicit music selections remain intact. Lyrics and online lookups
remain opt-in. Apple font binaries are not redistributed: the importer consumes
a local font the user is entitled to use. Noto remains the bundled fallback.

## Verified behavior

- Arch: **246 tests, OK, 2 skipped**, including native-extension staging compatibility, emoji import validation,
  idempotent user installation and escaped font names. Invalid outline settings
  are rejected before compositor dispatch or persistence.
- Native extension compiled and loaded on **Hyprland 0.56.2-4**. Firefox in
  tiling displayed close/minimize/maximize; clicking its actual minimize button
  moved the window to `special:forynarch-minimized`.
- Actual keyboard events: **Super+D** hid and restored the owned Firefox
  fixture, **Super+H** minimized it, and **Alt+Tab** restored it. Clicking
  Fullscreen in Arrange Window set `fullscreen=2`, position `[0,0]`, size
  `[1280,800]`; **Super+F** restored the previous tiled geometry.
- `tests/fixtures/focus-cursor-native.py`: **PASS**. Two owned tiled windows
  center the cursor after focus dispatch; converting them to floating and
  focusing alternately preserves cursor coordinates. The test releases shell
  popups before checking application focus and cleans up only its own processes.
- Native Noto import returned a user-local font URI and a valid fontconfig
  preference. The picker loaded its file chooser/font UI without QML errors.
- A compiled Qt MPRIS fixture supplied artwork and two native lyric lines.
  The shell reported `lyricsState=ok`, `lyricLines=2`; the MacShell lyrics view
  displayed them. Width-based scaling kept controls clear in the taller view.
- Native screenshots verified the five-row Control Center, new two-slider
  button, separate audio action and blue material. No recording tile appears in
  Edit Controls or old saved control lists after normalization.
- Color and independent tiling/floating outline preferences persisted through
  the system helper; both switches were separately set to false with a custom
  `#68d7e6` color. Settings > Desktop loaded the controls without QML errors.

## Anti Slop delivery gate

- **Hard gate — PASS:** requested MacShell visual vocabulary and Forynarch blue
  tone, retained source notices, no unrelated UI defaults.
- **Purpose — PASS:** real native minimize requests, functional window actions,
  persisted outline preferences and user-local font installation.
- **Motion — PASS:** existing staggered tile entry, animated audio-panel resize,
  music/lyrics transitions and brief rim highlights; reduced motion turns them
  off. No continuous widget screen capture or recording process.
- **Craftsmanship/accessibility — PASS:** visible action labels, retained
  accessibility names, keyboard shortcuts, consistent icon hit areas and bounded
  settings. Blue fallback secondary-text contrast is **8.67:1**. Glass uses actual compositor blur with a rim, rather than a blurred
  wallpaper image.

## Remaining hardware checks

Real touchpad motion after focus warps, mixed-DPI monitors,
third-party client titlebars and multi-device audio still need physical hardware
coverage. VirtualBox's absolute pointer can reassert host coordinates.
XWayland minimize behavior has source coverage but still needs a native client
fixture. The packaged extension currently advertises capabilities for new window
mappings; reopen applications after manually loading it into an existing session.
Apple glyph rendering is untested because no licensed Apple font was supplied.
Receiving applications can choose their own font. Live memory measurements do
not certify the installed-core 3,000,000,000-byte limit.
