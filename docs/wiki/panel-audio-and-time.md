# Panel, windows, sound and time

## Panel

Open Settings → Panel. The default Spaced layout leaves workspace and apps on
the left, clock and workspace slots in the center, and system controls on the
right. Compact brings the groups together. Group spacing offers 8, 12, 18 or 24
logical pixels. Apps, workspaces, clock, mode label, network, power and Show
Desktop can each be hidden. The mode label hides on narrow screens.

Hover an application for window previews; select a preview to activate its
window. Each preview has a close button. A single-window app button minimizes
its active window or restores an inactive/minimized window. Captures exist
only while the popup is open, stop after two unsuccessful attempts, and use
snapshots on software rendering. Live previews can be disabled in Panel settings.

## Floating windows and snap

Super+D or the Show Desktop button minimizes the active workspace's visible
windows. Repeat to restore them. Previously minimized windows remain minimized;
pinned windows are left alone. Activation raises floating windows.

In Settings → Desktop, enable Snap floating windows. Move a floating window
with Super+left drag, or drag an application's draggable title bar. Left/right
edges select halves, corners select quarters, the bottom selects a bottom half,
and the top maximizes. Release to apply the preview. Ordinary clicks, resizing,
pinned windows and tiled windows do not trigger snap. The observer timer runs
only during a potential drag, never at desktop idle.

The layout picker still offers native two-window pairs with a shared resize
border. Edge snapping positions individual floating windows; it does not park
unrelated windows to create a tiled pair. Manual per-window choices remain
independent of the workspace default for new windows.

## Real blur

Glass cards use translucent surfaces and Hyprland blur of content actually
behind them. Cards do not load or scale private wallpaper images. Settings →
Appearance controls glass, frost and motion. Disable effects for lower power
use. The desktop background itself is drawn once by swaybg.

## Sound

Click the panel speaker to choose the default output, change its volume, or
adjust each playing application's volume and mute state. All sound settings
opens the full input/output list with separate default input and output.
Applications appear when they publish playback streams. Multiple streams from
one application share a mixer row. Volume changes never move streams to a
different output: explicit application routing remains intact.
Devices and Bluetooth profiles remain managed by PipeWire/WirePlumber; no
additional mixer daemon is required.

## Date & Time

Click the clock or open Settings → Date & Time. Automatic time reports whether
network time is enabled and whether synchronization has completed. Search the
system timezone database by city or timezone, then Apply timezone. Interface
language stays English. Choose 12/24-hour panel time independently.

Manual time uses `YYYY-MM-DD HH:MM[:SS]` and requires automatic time to be
disabled first. Changes use timedatectl and normal system authentication.
Failed authorization is shown in the UI.

## Editable source

QML components live in `~/.config/quickshell/forynarch/`, helpers in
`/usr/local/bin/`, and snap observation in `~/.config/hypr/auto-snap.lua`.
Generated overrides remain in `~/.config/hypr/bindings-user.lua`; use the
shortcut editor for normal remapping and conflict detection.
