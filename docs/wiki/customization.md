# Customize your desktop

Open Search with **Super + Space** and choose Settings. Shortcut names below
refer to factory defaults; the shortcut editor can change them and detect clashes.

**Super + Q** and **Super + Return** open a terminal. If the pointer is over a
visible supported terminal window, the new terminal uses that terminal's local shell directory,
including changes made with `cd`. Otherwise it tries the focused terminal window and
then Home. Paths with spaces are supported. A foreground local editor uses its
parent shell's directory. Remote SSH directories and ambiguous shared terminal
servers or terminal multiplexers are not inferred. No polling service is used.

| Area | Available controls |
| --- | --- |
| Appearance | Navy/blue accent, glass, frost, application opacity, motion and reduced effects |
| Widgets | Switches, JSON packs, editable QML sources, grid placement, presets and global scale |
| Desktop shortcuts | Optional application icons, searchable app selection and a master display switch; off by default |
| Windows | Per-workspace floating/tiling, per-window floating, initial floating size and automatic arrangements |
| Shortcuts | Managed bindings, reassignment, conflicts, reset and generated user overrides |
| Hardware | Wi-Fi scan/connect, Bluetooth, input/output audio devices and defaults, displays and power controls |

**Super + Arrow** focuses a window in that direction. **Super + Shift + Arrow**
swaps in that direction. **Super + L** toggles floating for the whole workspace;
**Super + V** toggles the selected window. **Super + Ctrl + Space** opens window
arrangements. **Super + Ctrl + Arrow** places a floating window on a screen half.
Side-by-side and stacked pairs use native tiles with a shared resize boundary.
Other windows are minimized recoverably while pairing; restore the arrangement
to bring them back. Native drag-to-edge alignment is separate from half placement.
The arrangement picker also offers left, middle and right thirds for wider
screens. These floating placements can be resized individually and restored.

The main panel contains running applications alongside workspace controls.
Hover an application to see window previews and select a specific window.
The panel sections form a compact centered group. Application icons keep their
order while focus changes, with short hover/entry/indicator motion. Workspace
buttons have accessible names without a long hover tooltip.
**Super + period** opens emoji; GIF search requires the user's GIPHY setup.

Saved desktop preferences live in
`$XDG_STATE_HOME/forynarch/appearance.json`. Hyprland user bindings are generated
under `~/.config/hypr/`; use the shortcut editor for supported changes. Source
defaults live in `config/forynarch/hotkeys.json`, which is compiled with
`python scripts/hotkeys.py`. Do not change only generated bindings in a patch.

See [widget packs](widget-packs.md), [hybrid windows](../hybrid-floating-windows.md),
and [settings and hotkeys](../settings-and-hotkeys.md) for details. User settings
do not install optional software or enable developer services.
