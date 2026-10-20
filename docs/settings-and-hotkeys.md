# Settings and keyboard integration

Follow-up: [storage management and installer preparation](storage-and-installation-preparation.md)
adds a disk/partition explorer and non-executing review flows to Storage.

Audio follow-up: `AudioPage.qml` now uses live PipeWire device objects instead
of a one-time device snapshot. Outputs and inputs have separate lists, each
device has volume/mute controls, and the actual default is marked. Set default
uses Quickshell's documented preferred-default sink/source properties; the
badge follows the actual default, not merely the request. See the
[Quickshell PipeWire API](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Pipewire/Pipewire/).
Successful CLI stdout (including `ok`) is no longer used as a Settings message;
failed actions still show their error.

Verified on Quickshell 0.3.2-1, PipeWire 1:1.6.9-1 and WirePlumber 0.5.18-1:
two temporary virtual audio devices appeared without Refresh; GUI selection
changed both output and input defaults, and their volume/mute read back through
`wpctl`. Original defaults were restored and the QA devices removed. Hardware
levels were retained. Real speakers/headphones/USB/Bluetooth playback were not
tested. `bash tests/run-settings-feedback.sh` passed in the ordinary Arch
desktop session: successful `ok` output stays hidden and exit-7 stderr remains
visible. No settings are changed by that regression test.

Implementation and VM checks: 15 October 2026, Windows host time. The running
Live guest still reports 14 October UTC. This is a source and Live-preview
iteration, not a newly built ISO or an installed-system acceptance report.

## Scope and versions

The Glass desktop now has 13 searchable categories: Appearance, Panel, Desktop,
Network, Bluetooth, Sound, Displays, Power, Input, Storage, Privacy, Shortcuts,
and About. All shipped text is English. The existing glass, widget, storage and
developer-package policies remain in force.

Runtime checked: Hyprland **0.56.2-4**, Quickshell **0.3.2**, NetworkManager
**1.58.1-2**, and hypridle **0.1.8-2**. Dispatchers and monitor changes use the
installed release's Lua API. [Hyprland's current documentation](https://wiki.hypr.land/Configuring/Basics/Dispatchers/)
explains the transition from hyprlang beginning with 0.55. The existing builder
adapter still rejects unknown packaged examples/releases for review.

Affected source areas:

- `config/forynarch/hotkeys.json`, generated Lua, GUI and terminal guides;
  `scripts/hotkeys.py` is an author/build-time compiler.
- `SettingsCatalog.js`, `SystemPage.qml`, `SettingsPanel.qml`, `Choice.qml`,
  `ThemedSlider.qml`, and shell audio/page IPC integration.
- On-demand `forynarch-system`, `forynarch-display`, `forynarch-hotkey`,
  `forynarch-window-switcher`, and monitor-local workspace helpers.
- Target/Live packaging, the optional native idle user unit, Mako's DND rule,
  settings desktop entry, and behavioral tests.

## Shortcut precedence

The [Omarchy manual](https://omarchy.org/manual/hotkeys/) is the compatibility
reference. Existing Forynarch requirements take priority:

| Preserved binding | Forynarch action |
| --- | --- |
| Super+Space | Application search |
| Super+Q / Super+E | Terminal / Files |
| Super+C / Super+V | Close / toggle this window's floating state |
| Super+Arrows | Focus another window in that direction |
| Super+Shift+Arrows | Swap windows in that direction |
| Super+1–5 | Focus a local slot on the focused monitor |
| Super+Shift+1–5 | Move to that monitor's local slot |
| Alt+Tab / Alt+Shift+Tab | MRU cycle within the active workspace |

Compatible aliases include Super+Return, Shift+F, K, Esc, window/group controls,
workspace navigation and system-page shortcuts. Super+Ctrl+A/B/W/D/P opens
Sound/Bluetooth/Network/Displays/Power. Super+K opens the searchable guide.
The complete implemented list is [generated here](../config/forynarch/hotkeys.txt).

Unavailable applications and Omarchy-only services are omitted. Calendar-popup,
recording/OCR, width-bookmark, workspace-to-monitor transfer, sticky-window,
nightlight and unimplemented panel shortcuts are not advertised as working.
Clipboard stays with standard application shortcuts because Super+C/V already
have protected meanings. Workspace-default Super+Shift+V remains planned;
this patch does not convert existing windows or simulate a default-policy UI.

`hotkeys.py --check` rejects stale generated files. Native mouse drag/resize
remain from the verified packaged example and appear in both guides. The
packaged exit shortcut Super+M and extra number slots are removed. No implicit
close-all shortcut is introduced. Shortcuts can be reviewed in source; a GUI
key-rebinding editor is not yet implemented.

The MRU helper freezes order while Alt is held and clears the cycle on either
Alt release. Closed, hidden and other-workspace windows are excluded. No MRU
daemon is added. Monitor slot blocks are allocated persistently in
`~/.config/forynarch/monitor-slots.json`; unique hardware serials survive
connector changes, with connector names as the fallback. Duplicate serials
cannot establish stable hardware identity. Multi-monitor behavior has fixture
coverage, not physical multi-monitor acceptance yet.

## Implemented controls

| Category | Controls and actual backend |
| --- | --- |
| Appearance / Panel / Desktop | Existing wallpaper identity, accent, shell/application glass, opacity, blur, reduced motion, motion blur, panel arrangement, individual widget visibility/order/size/side and clock format |
| Network | Adapter state, Wi-Fi radio, native connection editor for saved networks, authentication, Ethernet, VPN, DNS and IP configuration through NetworkManager |
| Bluetooth | Adapter power, discovery, paired-device connection/disconnection through Quickshell's BlueZ interface; pairing/passkey interaction delegated to a visible `bluetoothctl` agent terminal |
| Sound | Real default speaker/microphone volume and mute; available output/input devices and default-device selection through PipeWire/WirePlumber |
| Displays | Output selection, reported resolution/refresh modes, scale, rotation, position, adaptive sync, variable-frame rendering and compositor FPS diagnostics |
| Power | Battery state, detected backlight brightness, optional idle lock, screen blank and suspend timers; existing confirmed session/power menu |
| Input | Keyboard layout, repeat rate/delay, pointer sensitivity and touchpad natural scrolling |
| Storage | Existing This Computer/drive view, Windows aliases and safe filesystem policy |
| Privacy | Real notification DND state, region capture and desktop-portal explanation |
| Shortcuts / About | Searchable generated guide; current kernel, processor, session type and a refreshable memory reading |

The network editor handles authentication; this panel does not collect or save
Wi-Fi passwords. Bluetooth scanning started by Settings stops on page exit or
panel destruction. No wireless radio is automatically enabled by opening a
page. Unsupported controls are disabled with an explanation.

Most system information is sampled once on page opening, after an action, or
on Refresh. Audio and Bluetooth use existing event-backed services. There is
no new always-running settings process or periodic compositor query. The
display-confirmation countdown runs only during a pending preview. Native
hypridle is started only when an idle policy is explicitly enabled.

FPS diagnostics report compositor rendering, **not game FPS or a game frame
cap**. Refresh rate remains the monitor mode's Hz. Variable-frame rendering
avoids unnecessary compositor redraws; VRR still needs compatible hardware.
The UI does not pretend that changing Hz guarantees higher game performance.

## Persistence and failure behavior

Typed preferences live in `~/.config/forynarch/system.json`. Only validated
booleans and enumerated values become `hypr/system-settings.lua`. Unknown
setting names and malformed values never reach compositor dispatch. Idle
ordering must put locking before blanking/suspend when those features are
enabled. Live passwordless accounts cannot enable locking. New idle timers
default to Never; no suspend is performed by this implementation's checks.

Display previews accept only reported modes, supported scale presets, whole
logical pixels and bounded coordinates. They cannot disable an output. The
rollback guard is armed before applying a change and runs independently of
Settings. Keep persists that output's setting in `hypr/monitors.lua`, preserving
other outputs. Revert or the 15-second guard restores the captured mode. Tokens
prevent an old guard from reverting a newer preview. Logical position remains
a coordinate field; a graphical monitor arrangement editor is still pending.

New target/Live manifests include `bluez` and `bluez-utils`, with service links
prepared for the next build. Repository metadata for **5.87-2** was inspected:
their required dependencies introduce no Python, Git, Node or compiler.
`bluez-utils` is used for the runtime Bluetooth agent, despite its general
package description mentioning development/debugging. No Blueman, complete
GNOME/KDE settings suite, or new Python runtime helper is installed.

New Live staging profiles select NetworkManager and remove releng networkd
enablement links to avoid competing connection managers. This does not change
the running VM's network service. The current older Live image has working
existing networking but **NetworkManager is inactive and BlueZ is absent**;
their hardware controls are therefore unavailable in this preview. No package
installation or forced network-service switch was performed during these checks.

## Research and remaining settings coverage

The category design draws on [GNOME's settings index](https://help.gnome.org/gnome-help/prefs.html),
[KDE System Settings](https://docs.kde.org/trunk_kf6/en/systemsettings/systemsettings/general.html),
and [Xfce's settings manager](https://docs.xfce.org/xfce/xfce4-settings/start).
GNOME provides a useful broad device/system taxonomy; KDE gives more granular
device and behavior controls; Xfce demonstrates focused dialogs for display,
input, preferred applications and sessions. These inform our design choices;
their daemons and entire desktops are not being imported.

[KDE power management](https://docs.kde.org/stable_kf6/en/powerdevil/kcontrol/powerdevil/)
and [Xfce's power manager](https://docs.xfce.org/xfce/xfce4-power-manager/start)
also identify AC/battery policy and inhibition as important. Forynarch uses
existing system services, respects idle inhibitors and requires hardware QA.

The following are an explicit backlog, not hidden omissions or working switches:

| Area | Next coverage and verification required |
| --- | --- |
| Networking | Integrated AP list, forget/reconnect, hotspot and airplane-mode coordination; native editor currently covers connection details. Test USB Wi-Fi and VPN plugins on an approved Linux test device. |
| Bluetooth | Native passkey dialog, trust/forget, battery data and multiple adapters. Test real headphones, keyboard and reconnect after suspend. |
| Displays | Visual monitor dragging, mirror/primary policies, fractional-scale app QA, HDR, ICC profiles, nightlight and hotplug recovery. Test two physical outputs and VRR-capable hardware. |
| Power | Separate AC/battery policies, lid behavior, sleep inhibitors, power profiles, charge thresholds and hibernate. Audit any new dependency chain; validate on a laptop. Do not expose hibernate before resume storage is configured. |
| Audio | Per-application routing/levels, channel balance and device profiles; verify actual playback/recording and Bluetooth profiles. |
| Input / Accessibility | Remapping UI, repeat preview, touchpad gestures/tap settings, tablets/touch, large text, high contrast, sticky keys and screen-reader integration. Test real input devices. |
| Applications / Session | Default apps, MIME associations, permissions where supported, autostart management and workspace-default policy with independent manual window overrides. |
| Region / Accounts | UI language, timezone, date/time, users/passwords and authentication. Keep shipped defaults English; privileged changes need the required approval flow. |
| System / Devices | Printer management, updates/recovery, firmware, hardware details and diagnostics. Add only audited components; developer groups remain opt-in. |
| Storage | Explicit alias editing/ambiguity UI and real removable-drive QA, retaining Windows fast-startup/hibernated-volume protections. |

## Verification

- Arch Live: `python -m unittest discover -s /opt/forynarch-preview/tests`:
  **78 passed**, no skips (`Ran 78 tests in 1.653s`). Covers generated guides, protected keys, local
  monitor allocation/reordering, MRU cycling and closed-window removal, invalid
  preferences, persistence, idle ordering, display validation, stale rollback
  tokens, preserving other monitor profiles and refusing to persist a failed
  idle-service policy, alongside existing tests.
- Windows: `powershell -NoProfile -File scripts/forynarch.ps1 -Action Check`:
  **exit 0**, 78 tests, **53 passed / 25 Linux-only skips** (`1.980s`); shell syntax and
  pipeline-plan checks included.
- Arch ShellCheck **0.11.0**: no findings across `scripts/*.sh`.
- Actual Hyprland reload: exit 0, empty `configerrors`. Cold-loaded Glass and
  opened all 13 categories. No QML type/reference/binding errors were found;
  upstream Qt Wayland text-input warnings remain, plus the expected missing
  `org.bluez` warning in this old Live image.
- Real keyboard injection: Super+Ctrl+D opens Displays. Runtime binding list
  confirms the protected Q/C/V meanings. FPS overlay read back as `bool: true`
  after enabling and `bool: false` after restoration.
- Same-mode display preview: the UI was closed while pending; the independent
  guard cleared the transaction and original geometry/mode remained intact.
  Physical mode changes, rotation, VRR and multi-monitor rollback remain untested.
- No Wi-Fi/Bluetooth pairing, real sleep/hibernate, real-drive writes, package
  installs, account edits or host security changes were executed.
- Short Live memory sample after closing Settings: six readings, five seconds
  apart, peak **1,582,882,816 bytes** (1.58 GB decimal), **swap 0**, collector exit
  0 against **3,000,000,000 bytes**. Existing applications were retained. This
  demonstrates headroom in that session, not installed idle-memory acceptance.

Preview screenshots and measurement logs are ignored under `out/virtualbox/`.
The existing ISO is unchanged. Next release check: recover the unresponsive
builder, build a fresh disposable Live image with NetworkManager/BlueZ, then
perform physical-device checks and the independent installed-target package
and idle-memory acceptance matrix. Do not force-reset the builder as part of
this settings task.

## Network speed test

Settings > Network includes **Run speed test**, which opens
[Fast.com](https://fast.com/en/) in the configured default browser. It uses the
existing Network page's styling and keyboard support, adds no packages or
background activity, and starts only when clicked. The compact Control Center
Wi-Fi view keeps its existing layout. If no browser can be opened, the page
shows an error pointing to Default Apps. A browser must be installed; choosing
this feature does not install one automatically.
