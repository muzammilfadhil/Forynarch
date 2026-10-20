# Blue Hour desktop implementation and review

Follow-up: [Hybrid and floating windows](hybrid-floating-windows.md) adds
automatic utility floating, adjustable initial sizes, native edge resizing and
File Manager client decorations. The recorded R1 memory run below still refers
to R1; it is not relabeled as a benchmark of the later window update.

15 October 2026. This is an experimental build with a tested installed core,
not a general hardware release. Earlier documents describing an inert installer
or unmeasured installed memory are historical; the evidence below supersedes
those specific statements.

## Intent and affected components

The desktop now ships widget packs and an editable desktop layout, a native
emoji picker, isolated web apps, music visualisation, window modes and a real
dedicated-disk installer. Implementation lives in `config/quickshell`,
`config/hypr`, `scripts/integrate-desktop.sh` and the corresponding
`scripts/forynarch-*` helpers. Catalog changes are in `packages`; regression
fixtures and runners are in `tests`. All shipped interface text is English.

The visual direction remains navy and blue, with finite panel transitions,
glass, keyboard focus indicators and a reduced-motion option. Glass is now the
default build shell; `--desktop-shell classic` remains available.

## Widgets and emoji

Ten widget types are available: analog clock, calendar, greeting, music,
digital clock, focus timer, memory, battery, quick launch and keyboard guide.
Essentials, Focus, Laptop and Minimal packs provide starting layouts.
Only the original four widgets are enabled by default. The editor supports
dragging, grid snapping, per-output positions, sizing, presets, Save and Cancel.
Normal desktop gaps pass mouse input through. Resource metrics run only when
a corresponding widget is enabled; the focus timer runs only while active.

Super + period opens the system-styled emoji picker. Its offline Unicode 17
catalog contains 3,944 fully qualified emoji, search, categories, skin tones,
recents, symbols and kaomoji. Selection copies the character and attempts a
Wayland paste into the original application. If focus changes, another popup
opens or the user moves to another monitor, it keeps the clipboard copy and
does not paste into an unexpected application. This is not a complete clone
of every Windows clipboard/history function.

GIPHY search is optional, uses the user's API key and includes attribution.
It copies a GIF link rather than pretending every Linux application accepts
binary GIF insertion. The online API has not been exercised without a key.
See the [GIPHY API requirements](https://developers.giphy.com/docs/api/).

Noto Color Emoji is bundled. A locally installed Apple Color Emoji font can
be preferred, but no Apple font is redistributed: an approved redistribution
license has not been established. See [Apple Fonts](https://developer.apple.com/fonts/).
The Unicode catalog and license are recorded in the repository.

## Desktop integration

Music uses MPRIS. A single Cava process produces spectrum data only while music
is playing and its widget is visible with motion enabled. Pause, hidden widgets
and reduced motion stop it. Window modes include dwindle, master, scrolling and
floating defaults. Changing the default affects new windows; applying it to
open windows is a separate explicit action. Manual overrides remain independent.
The mode helper releases its lock before refreshing shell IPC, fixing a native
deadlock discovered during review.

Search exposes power and sign-out actions; Super + Escape is removed. Popup
surfaces release layer keyboard focus while closing, and a bounded helper
returns focus to the current application on the current monitor. Logout exits
Hyprland normally so SDDM's session helper can finish, while logind removes the
remaining session processes. Force-terminating the login session was rejected
after it left the tested SDDM display without a fresh greeter.

Web apps have independent private browser profiles for separate accounts.
Chromium-family browsers use app windows; Firefox uses a separate ordinary
window and profile. Removing a shortcut retains account data, as stated in
the interface. Web app creation never installs a browser automatically.

Thunar entries are named File Manager and use the project icon. Common file
preferences are exposed in Settings; the upstream advanced preferences remain
available. Upstream credits and licenses are preserved. Remote access services,
Avahi advertising and systemd's SSH socket generator are disabled by default.
OpenSSH remains a required dependency of Arch's `gcr-4`; its presence does not
mean an SSH server is enabled. NetworkManager is the selected network manager.

## Installer and package boundaries

Install Forynarch is a separate nine-stage application with account, keyboard,
timezone, driver and software review. Its privileged executor receives private
JSON over stdin, rechecks disk identity and blockers, requires the typed erase
confirmation and reports actual process progress. Passwords do not enter
arguments, public review JSON or progress logs. A sanitized root PATH, explicit
Archiso executable permissions and robust locale generation fix failures found
in real VM installation rather than only source tests.

Only dedicated whole-disk ext4 installation is executable in this revision.
Alongside/manual layouts, encryption and unsupported driver combinations remain
blocked. The advanced partition manager remains separate. No claim of tested
dual boot, NVIDIA setup or hibernation is made.

Browser and productivity choices appear only in OS setup. Firefox is available
in Live; the installed core receives no browser unless selected. Git, Node,
npm, pip, IDEs and developer groups are unchecked. Python is an explicitly
documented unavoidable Arch runtime dependency of the multimedia/Waybar stack,
not a selected developer toolchain. Live-only trial installation uses a bounded
active-local-session authorization policy that is absent from the target.

## Versions and verification

Native validation used Arch Linux, Hyprland 0.56.2, Qt 6.12, Archiso 91,
VirtualBox 7.2.20, Cava 1.0 and Noto Color Emoji 2.051. Software-rendered Qt was
used in the VMs. Physical GPU performance is a separate acceptance test.

Latest full source run: **129 Python tests passed in 2.836 seconds**, no skips;
Bash syntax and ShellCheck passed. The Archiso boot-policy check inspected
eight entries, changed five files, then changed zero files on its second run.

Native VM results:

| Check | Result |
| --- | --- |
| Emoji search, recents, widget packs, geometry, actual Wayland paste | Pass |
| Widget pack selection, Cancel restore, Save persistence, Cava shutdown | Pass |
| Search/settings/controls/drives release focus with closing surfaces still mapped | Pass |
| Window-mode defaults, existing windows, manual overrides, all tiling modes | Pass; under 15-second deadlock timeout |
| Real PipeWire spectrum and MPRIS metadata | Pass; silent virtual audio sink |
| Cava pause/hidden/reduced-motion lifecycle | Pass |
| Two real Firefox web apps with different private profiles | Pass |
| Installer pages, shader, validation, secret isolation, modal focus | Pass; executor disabled in this fixture |
| Executor handoff, erase confirmation and process progress | Pass; fake privileged child in this fixture |
| Real offline graphical install to a verified blank 48 GB VDI | Pass; zero optional groups; EFI boot and password login |
| Kath video greeter and passwordless field visibility | Pass; actual installed SDDM |
| Sign-out, fresh greeter, passwordless sign-in and application cleanup | Pass; zero original user processes remain; uptime continues without reboot |

The focus fixture holds closing surfaces mapped and allows IPC to finish before
sending the key. It tests focus release, not a guaranteed response time on a
CPU-starved VM. Qt emitted text-input warnings in several passing fixtures;
these are recorded rather than counted as a warning-free run.

## Installed memory gate

On the installed core QA VM, with two virtual CPUs, 4 GiB assigned memory,
the four default widgets, glass and motion enabled, after five minutes idle:

| Sample | MemTotal minus MemAvailable, bytes | Swap used, bytes |
| --- | ---: | ---: |
| 1 | 1,222,643,712 | 0 |
| 2 | 1,222,623,232 | 0 |
| 3 | 1,222,623,232 | 0 |
| 4 | 1,222,623,232 | 0 |
| 5 | 1,222,623,232 | 0 |
| 6 | 1,224,302,592 | 0 |

The maximum is **1.2243 GB decimal**, below the 3,000,000,000-byte gate.
This was an installed filesystem, not a Live snapshot. The temporary QA access
agent was removed before sampling, and no greeter video process remained after
login. The initial raw record is `out/virtualbox/qa-http/metrics-initial-installed.log`.

### Final R1 installed result

The R1 ISO completed a second real offline installation to its separately
verified blank 48 GB VDI. Its EFI installation booted with the ISO ejected,
generated the English locale correctly, and accepted passwordless sign-in
through Kath without manual repairs. No optional groups were installed.

After a further five minutes idle, six samples eight seconds apart were:

| Sample | MemTotal minus MemAvailable, bytes | Swap used, bytes |
| --- | ---: | ---: |
| 1 | 1,184,571,392 | 0 |
| 2 | 1,182,535,680 | 0 |
| 3 | 1,182,683,136 | 0 |
| 4 | 1,182,810,112 | 0 |
| 5 | 1,195,487,232 | 0 |
| 6 | 1,195,581,440 | 0 |

**Final R1 peak: 1.1956 GB decimal; memory gate passed.** Assigned RAM was
4 GiB, reported MemTotal 4,077,137,920 bytes, with two virtual CPUs and the
four default widgets, glass and motion. No extra QA access agent was installed
in this target, no foreground test application remained, and no greeter video
process appeared in the post-login process inventory. Records are
`out/virtualbox/qa-http/metrics-r1-installed.log` and `audit-r1-installed.log`.

## Remaining risks and next acceptance work

Final-image cold boot, installation and installed measurements passed as above.
Physical Wi-Fi/Bluetooth scanning and pairing, multiple monitors,
battery/sleep/hibernate, real GPU power usage, external browser runtimes and
an actual selected Flatpak download remain hardware/network acceptance work.
The native Bluetooth D-Bus fixture tests pairing protocol behavior, not a radio.
The next smallest hardware test is booting the final ISO normally, checking
Wi-Fi scan/connect and measuring the installed core after five minutes idle.
