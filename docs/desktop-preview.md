# Navy desktop preview

The current source and running Glass VM also include
[expanded settings and shared hotkey guides](settings-and-hotkeys.md), including
monitor-local slot allocation. The single-monitor descriptions below refer to
the older ISO; the new settings iteration has not been rebuilt into that ISO.

The new [Glass shell implementation](glass-shell.md) now runs in the Live test
VM with shader surfaces, backdrop blur and working appearance controls. Its
short VM memory checks pass below 3 GB. The previously built ISO is unchanged;
glass-profile ISO, installed-target and hardware acceptance tests are pending.

All shipped Linux interface text, menus, help and prompts use English. The
installed target defaults to en_US.UTF-8; the English Live session uses C.UTF-8.
Timezone selection does not change interface language.

The next user-selected direction is the blue adaptation of end4-pC screenshot 3,
with a strict idle RAM limit below 3 GB. See the [reference analysis and memory
protocol](end4-reference-analysis.md). The SVG concept illustrates planned widgets
and settings; the existing ISO has not gained those features yet.

The desktop uses opaque navy surfaces, DejaVu typography, a compact 38px
panel, a geometric Forynarch SVG wallpaper and restrained window borders.
Foot, Fuzzel, Mako and GTK applications share the palette. Blur and animation
remain disabled. This iteration does not claim battery or hardware performance gains.

Waybar now uses the supported `config.jsonc` filename and explicit config/style
arguments. The earlier `config.json` fell back to the distribution's default
configuration and missing icon-font glyphs. Text labels avoid extra icon-font
dependencies. Only the known `Virtual-1` output is constrained to scale 1;
physical displays keep the packaged automatic scaling behavior.

Swaybg is a core desktop wallpaper dependency, not a developer add-on. In the
tested snapshot swaybg 1.2.2-1 adds 33.60 KiB installed and uses existing
Wayland/Cairo/GdkPixbuf dependencies. SVG rendering was verified in the VM.
The wallpaper process is started once per session. No extra polling daemon
or full desktop toolkit was added.

Hyprland 0.56.2 uses Lua dispatch expressions. Waybar 0.15.0's native
workspace click handler still sends legacy commands. Five custom slot buttons
use `forynarch-workspace` with validated numeric slots, an atomic runtime cache
and refresh signals on compositor workspace/config events. Status rendering
does not call the compositor. These are **single-monitor preview slots**;
monitor-local mapping and workspace default modes remain M2 work.

Click the brand for applications; right-click for Files, Terminal, Network,
shortcuts and Session. Network opens nmtui. Session sign-out/power actions
require a second confirmation. Lock is omitted on the passwordless Live
session; installed-session Hyprlock authentication remains unverified.

**Known issue — hover highlight on brand/tray:** `#custom-ws1..5` and
`#custom-session` in `config/waybar/style.css` each define their own
`margin`/`border-radius`/`:hover` background, so their highlight box hugs the
label. `#custom-brand` (left) and `#tray` (right) only set `padding`; they have
no `margin`, `border-radius` or `:hover` rule of their own. The pointer
highlight seen on those two therefore falls back to GTK's default focus/hover
box, which does not line up with the visible label the way the other modules
do. Fix would be to give `#custom-brand` and `#tray` the same
`margin: 5px 2px; border-radius: 6px;` plus an explicit `:hover { background:
#1c2b44; }`, matching the existing workspace/session modules. Not applied yet;
left as a note pending user confirmation and a real Hyprland/Waybar session to
verify the hover box visually before touching `style.css`.

The generated Live profile creates a non-wheel `liveuser` in a Live-only
oneshot unit, then tty1 logs in through agetty/PAM. Its normal login starts
`dbus-run-session start-hyprland`. Tty2 remains a recovery console.
Neither the Live account/service nor recovery tooling belongs to the separate
installed target payload. Developer package selections remain off by default.

To preview files in an already authorized disposable Live VM with swaybg and
liveuser available, transfer the source and run:

```bash
bash scripts/apply-desktop-preview.sh --approve-live-preview
```

The helper backs up the existing user's configuration in Live RAM, verifies
the installed Hyprland version/example and validates Foot/Fuzzel configuration.
It does not install packages or restart the active desktop session.

Validation: see [Live VM test evidence](../tests/live-vm-2026-10-14.md).
Pending gates include installer matrices, actual hardware, audio playback,
lock authentication, multi-monitor workspaces and power measurements.

References checked against installed versions:
[Hyprland 0.56 CLI](https://wiki.hypr.land/0.56.0/Configuring/Advanced-and-Cool/Using-hyprctl/),
[Hyprland events](https://wiki.hypr.land/0.56.0/Configuring/Advanced-and-Cool/Expanding-functionality/),
[Waybar config](https://github.com/Alexays/Waybar/wiki/Configuration),
[Waybar 0.15 workspace handler](https://github.com/Alexays/Waybar/blob/0.15.0/src/modules/hyprland/workspace.cpp),
[Swaybg](https://github.com/swaywm/swaybg).
