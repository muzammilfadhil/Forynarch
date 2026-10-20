# Panel visibility and battery telemetry, R5.8.3

The bar's existing visibility controls now cover its remaining buttons, including
the launcher, background apps, notifications, audio, Control Center, battery and
Settings. The selections persist in the existing appearance state and work with
both bar styles. Empty groups disappear and can be restored without a visibility
binding cycle. Hiding the launcher reclaims its reserved application space.

The battery indicator opens an independent popup instead of launching all
Settings. It shows per-battery power and status, optional energy/health/temperature
and cycle fields, estimated or hardware-provided remaining time, and separate
adapter telemetry. The same details appear in Power settings.

The helper reads the Linux power-supply ABI without privileges or side effects.
Micro-watts convert to watts; a current/voltage fallback uses micro-amps times
micro-volts. Energy and charge units remain separate. Missing, non-finite or
invalid readings remain unavailable rather than becoming zero. Charger ratings
and configured limits are not presented as consumption. Device-scoped and absent
batteries are excluded, and multiple battery capacities are weighted by energy
when comparable energy readings are available.

## Files and versions

Runtime: `DesktopPanel.qml`, `PanelComponents.qml`, `SettingsPanel.qml`,
`SystemPage.qml`, `shell.qml`, `Icon.qml`, `BatteryModel.qml`,
`BatteryDetails.qml`, `BatteryPanel.qml`, `scripts/forynarch-battery.py`.
Build integration: `scripts/integrate-desktop.sh` and `scripts/forynarch.sh`.
Tests: `test_battery.py`, `BatteryPanelFlow.qml`, `run-battery-panel.sh`.

The implementation uses the existing Python runtime, Quickshell 0.3.2, Qt 6.12
and Hyprland 0.56.2 from the frozen 18 October core. It adds no packages, default
developer tools, resident processes or power-setting writes. The shell schedules
transient reads at 30 seconds for the enabled bar indicator and 3 seconds for an
open battery view; reads stop when neither is needed. No new installed-memory
benchmark is claimed.

## Verification

- Windows and Arch: 11 telemetry tests passed, covering charging/discharging,
  signed current, micro-unit conversions, energy versus charge, actual zero versus
  unavailable data, multiple batteries, hot removal and adapter ratings.
- Arch: 17 existing system-settings tests passed.
- Native Wayland, classic and MacShell bars at 800, 1024 and 1280 pixels:
  all 15 panel switches toggled off/on, empty groups disappeared
  and returned, watt/time/unavailable states rendered, battery popup opened from
  the bar, Power settings and close actions worked, and the no-battery indicator
  disappeared. Existing panel tests passed 100 packing permutations and 20 metric
  boundaries. All six cases checked actual clock-card/control-group bounds.
  Narrow layouts shorten the date, battery label and button spacing
  rather than overlapping the clock. Seven new preferences were also saved, restored as disabled after
  a real shell restart, then re-enabled. These are disposable-VM fixtures, not
  real battery measurements.

## UI delivery check and limits

The owner-selected navy and pale-blue identity is retained: energy 2, rhythm 2,
motion 2. One large watt reading anchors each battery section; small aligned
labels expose supporting measurements. The popup reuses the shell's short motion
and reduced-motion preference, and its denser glass background keeps numbers
readable over bright wallpaper. No decorative assets, continuous animation or
charts without data were added. Plain-text status accompanies every reading.

Against the worst-case composited light-wallpaper background, secondary text
contrast measured 7.98:1 and primary text 11.16:1. Controls reuse existing visible
keyboard focus and Enter/Space handling. A real VM keyboard Escape event closed the open popup and the shell reported
`batteryOpen: false`. The popup supports Escape and outside
click dismissal and scrolls for multiple batteries.

Physical charging/discharging, vendor-specific AC readings and multi-battery
hardware still need laptop acceptance. Hardware may omit power, temperature,
health or time. The next hardware check is to open the popup on battery, connect
the charger, and confirm status and watts agree with that laptop's sysfs values.
See [user documentation](wiki/panel-and-battery.md).

## Final artifact acceptance

`forynarch-2026.10.18-blue-hour-r5.8.3.iso`, built on 19 October from the
frozen 18 October core, is 3,839,197,184 bytes. Builder and Windows SHA-256 match:
`8c985aa2c7df4936fa87fb2a3cce5dbba6d21b060be65410768abc095fcae899`.

Image verification matched 13 source files in the Live overlay and actual
SquashFS, and 10 desktop/helper files inside the compressed target rootfs. The
independent installed core remains 573 packages, with unselected developer groups
absent. The battery helper has executable permissions in the target archive.
A fresh UEFI boot from the Windows ISO verified all source hashes, the liveuser
configuration, battery helper, installer availability and absence of target disks.
The actual Live helper also passed its forced-ASCII UTF-8/live-log/child-result
probe. The new battery popup opened successfully in the fresh Live desktop.
No personal disk was written and no installed-memory benchmark was repeated.
