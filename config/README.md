# Desktop configuration source

Current Glass settings and keyboard controls are described in
[Settings and hotkey integration](../docs/settings-and-hotkeys.md). The new
workspace helper allocates stable per-monitor blocks of five slots; physical
multi-monitor acceptance and workspace-default T/F/M policy remain pending.
The older single-monitor notes below describe the original ISO preview.

The navy preview includes Waybar, Foot, Fuzzel, Mako, GTK3/GTK4 preferences
and an installed-session Hyprlock configuration. Wallpaper source is in
assets/wallpapers. Hyprland Lua is adapted from the actual installed 0.56.2
package example; unknown releases or changed example structure fail review.

The updated ISO was cold-booted in a new UEFI VirtualBox VM with VMSVGA and
3D enabled. Ordinary-user autologin, terminal, launcher, event-updated workspace
status, Thunar's GTK3 dark theme and session cancellation passed. Foot/Fuzzel
configuration checks and shell validation also passed. See the detailed
[VM evidence](../tests/live-vm-2026-10-14.md).

Waybar must load config.jsonc and style.css explicitly. Its five slot buttons
use the minimal forynarch-workspace helper for Hyprland's Lua dispatch syntax.
They are a single-monitor preview; monitor-local mapping and workspace T/F/M
defaults remain M2 work. No periodic compositor polling was added.

Live-only account setup and agetty overrides are in live/. They are excluded
from the independent installed-target payload. Passwordless Live mode omits
Lock. Installed-user lock authentication, GTK4 application appearance, audio
playback and physical hardware behavior remain unverified.

The desktop uses packaged DejaVu and text panel labels; no icon-font dependency
is necessary. Blur and animations stay disabled. Swaybg displays the original
SVG wallpaper once per session. Package policy remains choice-first: developer
tool groups are not selected by this styling work.
