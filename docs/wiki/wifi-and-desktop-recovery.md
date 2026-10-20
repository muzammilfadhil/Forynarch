# Wi-Fi and desktop recovery

In the MacShell Control Center, click the Wi-Fi **name or chevron** to open
nearby networks. The round Wi-Fi icon turns the radio on or off. Scan, choose
a network, and enter its password when prompted. Saved networks reconnect
through NetworkManager; enterprise connections use Advanced network settings.
Closing the network pane stops its scanner and clears any password input.
Wi-Fi settings remain available when no adapter is detected, with an explanation
of the unavailable hardware. A VirtualBox Ethernet adapter is not a Wi-Fi radio.

The Control Center tracks the active SSID and radio state. While it is open,
cached NetworkManager device and access-point information is checked every
2.5 seconds as a fallback for a missing active network in the shell model.
This check does not trigger Wi-Fi scans, request passwords, or run at idle when
the Control Center is closed. SSIDs and connection names containing colons or
backslashes are parsed without treating them as commands.

Control Center buttons keep accessible names and keyboard focus outlines.
Hovering them does not show explanatory tooltips. Escape returns from the
network pane to the control grid; another Escape closes the Control Center.

Widget sizes are 80%, 100%, and 120% in Edit Widgets. Each surface follows its
loaded card's height, including custom cards. Music-card height changes are
applied with the native surface resize so the smaller surface does not clip an
older, still-animating card. Playback button motion and glass remain enabled
according to the user's appearance preferences.

Fastfetch shows the Forynarch mark from
`/usr/share/forynarch/branding/terminal-logo.ansi`. Its source is
`assets/branding/logo.svg`; `scripts/configure-branding.sh` generates the
terminal representation. Edit `~/.config/fastfetch/config.jsonc` to change it.
The shipped information list is OS, Host, Kernel, Uptime, CPU, Memory, and GPU.
Fastfetch chooses the logo position automatically for the terminal width.

Repeated `windows.lua` focus errors must be fixed in the configuration rather
than hidden. The focus callback now ignores unmapped, hidden, expired, and
incomplete windows before using geometry, and never warps the cursor for a
floating window. The release tested here uses Hyprland 0.56.2 and Quickshell
0.3.2. Older Live media must be replaced or patched; editing the repository on
Windows does not change an already booted USB session.

Primary API references: [Hyprland window object implementation, v0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaWindow.cpp),
[Quickshell NetworkDevice](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/NetworkDevice/).
The installed Hyprland Lua stubs and Quickshell 0.3.2 runtime are also checked
when validating this release.
