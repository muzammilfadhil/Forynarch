# Panel, sound, snap and time review — R4.6

## Intent and files

Restore the spaced panel default and expose layout/visibility settings; use
normal window selection, activation and Show Desktop; make edge snap respond to
real pointer drags; remove per-widget wallpaper copies; add output selection,
application volume and Date & Time.

Changes affect Quickshell panel/settings/audio/preview components,
`auto-snap.lua`, window-control and shortcut helpers, generated catalogs, the
date-time helper, terminal branding and staged-root integration. No additional
target package or permanent service is introduced. Chafa is builder-only.

## Versions and implementation

Release artifact: `out/iso/forynarch-2026.10.16-blue-hour-r4.6.iso`,
3,966,468,096 bytes, SHA256
`c92611bd1997381ef69fe34663ff922c406dd42ca4df096b0c484ce86a9520c7`.
Builder/Windows hashes and exact-ISO cold boot passed. Its Live snapshot with
the Welcome overlay still open peaked at 1,243,033,600 used bytes, swap 0.
This is not an installed-core or clean-desktop benchmark. These changes are
also included in R4.7; see the [R4.7 report](experimental-os-vm-review.md).

Native checks use Hyprland 0.56.2-4, Quickshell 0.3.2-1, Qt 6.12 and systemd
262-1. Lua uses release window geometry, passive mouse bindings and managed
timers. Key strings use ` + ` separators. No unsupported `config.unload` event
is registered. The timer is disabled outside gestures. Playback streams have
`isStream && isSink` in this release, verified against an actual stream.

- Spaced default, Compact option, adjustable gaps and group switches; center
  content remains centered and the right island sizes to its controls.
- Single-window buttons minimize/restore; grouped windows have real previews
  and close controls. Software rendering uses snapshots. Failed captures stop
  after two attempts. Focus changes update the model without spawning helpers.
- Super+D toggles Show Desktop, retaining prior minimization and skipping
  pinned or replaced windows. Floating drag previews and edge/corner snap work
  independently of native paired layouts and per-window overrides.
- GlassCard no longer creates wallpaper images or shader sources per card;
  Hyprland blurs actual content behind surfaces, including widget-pack, layout,
  desktop-shortcut and Live Welcome dialogs.
- Output selector and application mixer share the existing PipeWire service.
  Volume changes leave application output routing intact.
- Date & Time exposes synchronization, timezone search/apply, manual time and
  12/24-hour format. Writes use system authentication.
- Alacritty uses the terminal icon. Fastfetch includes hardware, display,
  packages, shell, storage and memory with artwork generated from the canonical
  SVG. Existing customized configurations are preserved.

## Verification before ISO build

- Arch builder: **193 tests, OK (2 skipped)** (Node/Zsh unavailable on the
  builder host); generated hotkeys, Bash syntax and ShellCheck passed. New
  coverage includes date/time validation, Show Desktop recovery, snap geometry
  and idle lifecycle, and passive observer conflict handling.
- Live VM: Date & Time loads UTC and synchronized network time. Manual controls
  are disabled while automatic time is enabled.
- Live VM: two virtual outputs and a real playback stream were created for QA.
  The UI selected Speakers as default and changed the player to 34%; pactl
  confirmed that playback remained on Headphones. Fixtures were then removed.
- Real Super+mouse drag to the left edge produced a floating window at `[4,68]`,
  size `[633,728]` on 1280×800, leaving panel space.
- Show Desktop hid two windows, then restored only the window not previously
  minimized. Activating the other window restored and focused it:
  `SHOW_DESKTOP_PRESERVES_PRIOR_MINIMIZE_AND_ACTIVATION_OK`.
- Grouped previews captured actual terminal contents; selecting the first
  preview focused its matching compositor address. Spaced/Compact rendered;
  actual background blur showed wallpaper/windows behind surfaces. Hyprland
  config errors were empty after fixes.

## Remaining checks

The checks above use patched Live files. Final artifact hash, cold boot and Live
memory observations are recorded after build. A fresh installed-core idle
measurement is still required for the 3,000,000,000-byte release gate; Live RAM
is not that benchmark. Physical multi-monitor drag, fractional scaling, hardware
preview refresh, Bluetooth audio switching and authenticated time writes need
hardware or an installed test account. Geometry tests cover scaled/rotated
negative monitor coordinates but do not replace those hardware checks.

Official interfaces: [Hyprland v0.56.2 Lua windows](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaWindow.cpp),
[Quickshell PipeWire nodes](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Pipewire/PwNode/),
[systemd timedate service](https://github.com/systemd/systemd/blob/main/man/org.freedesktop.timedate1.xml).
