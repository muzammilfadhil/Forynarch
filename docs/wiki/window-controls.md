# Window controls, focus and desktop shortcuts

| Shortcut | Action |
| --- | --- |
| Super + F | Enter or leave fullscreen, including the panel area |
| Super + Alt + F | Maximize or restore within the usable desktop area |
| Super + H | Minimize the focused window |
| Super + Ctrl + M | Alternate minimize shortcut |
| Super + Ctrl + Shift + M | Restore the last minimized window |
| Super + D | Show the desktop; press again to restore the group |
| Alt + Tab | Switch applications, including minimized windows |
| Super + Ctrl + Space | Open Arrange Window |

Arrange Window includes explicit Maximize, Fullscreen and Minimize actions above
the placement choices. Fullscreen hides the panel; maximizing leaves its space
available. Floating snap placement stays independent of other windows. Change
shortcuts under Settings > Shortcuts; the editor checks conflicts.

The application bar restores a minimized app when selected. Its hover preview
also provides window actions. Minimized apps keep running. Closing an application
follows its own background/tray behavior.

## Native titlebar buttons

GTK defaults include close, minimize and maximize in both floating and tiling
modes. Forynarch's small native Hyprland extension advertises the Wayland minimize
capability and forwards native application minimize requests to the existing
shell window manager. It also handles XWayland minimize requests. Firefox's
actual minimize button was verified in tiling mode; appearance still depends on
the application's own decorations.

The extension uses Hyprland's public event/protocol APIs and validates the full
plugin ABI fingerprint before loading. Its build tools remain on the builder.
After a Hyprland/graphics library update, rebuild and verify the extension against
the installed release; a mismatched extension refuses to load. Keyboard and bar
minimization continue to use the independent existing helper.

## Focus behavior and outlines

Keyboard focus changes center the pointer in a tiled window. Floating windows
keep the pointer where it was, including Alt + Tab. Automatic compositor warps
and cursor restoration after non-mouse input are disabled. VirtualBox absolute
mouse integration can still impose the host pointer position on physical motion;
test relative mouse/touchpad behavior on real hardware as well.

In Settings > Desktop, focused window outlines have independent switches for
tiling and floating. Select a preset color or enter a six-digit hexadecimal
color. Turning off an outline makes the focused border match the inactive
border; it does not change focus or the application's own titlebar colors.

## Audio and music

The speaker button opens audio controls. The adjacent two-slider icon opens
Control Center. Bar and Control Center appearances remain independently selectable
in Settings > Panel. The MacShell Control Center has a muted blue glass tint,
tile entry motion and animated audio-panel resizing. Screen recording controls
have been removed.

New profiles use the MacShell music widget. Existing explicit style choices are
preserved; select MacShell in Settings > Desktop > Music widget to change them.
The player shows artwork on the left, playback controls and a lyrics toggle.
The lyrics view uses player-supplied lyrics first, with optional online LRCLIB
lookup as documented in [the media guide](screenshots-clipboard-and-media.md).
The glass surface uses actual compositor blur with an optical rim and a brief
hover highlight; it does not run a continuous screen capture or blur a wallpaper
crop. Reduced motion disables the highlight and transitions.

Fastfetch now uses one text column, with OS, host, kernel, uptime, CPU, memory and
GPU aligned together. The old side-logo layout is disabled. Branding assets
remain available separately for user customization.

Primary references: [Hyprland 0.56.2 protocol source](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/protocols/XDGShell.cpp),
[plugin ABI](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/plugins/PluginAPI.hpp),
[cursor settings](https://wiki.hypr.land/Configuring/Basics/Variables/#cursor),
and [GTK decoration layout](https://docs.gtk.org/gtk3/property.Settings.gtk-decoration-layout.html).
## App titlebar exceptions (R5.8.8)

Settings > Desktop > Window controls lets you keep an app's own controls or
restore the Forynarch titlebar for an individual floating app. Use Refresh to
pick a running class, or add an exact class manually. Remove a saved override
to return to the common default. Changes do not change floating/tiling modes.

Chrome browser windows use their own controls. Frameless Forynarch web apps
keep external controls; browser-prefix patterns do not exclude them. Exact
common exceptions also cover Discord variants, Vesktop, Steam, Mudil Music
and selected headerbar apps. Other Electron and KDE apps are not excluded as
a group. If an app's own titlebar preference is disabled, restore Forynarch
controls for its class. See [R5.8.8 patch and commands](../installed-patch-r5.8.8.md).

