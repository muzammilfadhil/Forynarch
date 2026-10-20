# Hotbar, window previews and snap layouts — 16 October 2026

## Intent and files

Keep running applications inside the main panel, replace count tooltips with
clickable window previews, and support free floating alongside automatic window
arrangements. Give launcher actions and settings sections distinct icons.

- `DesktopPanel.qml`, `RunningApplications.qml`, `WindowPreviews.qml`: one panel,
  compact application strip, native capture and window selection.
- `WindowLayoutPicker.qml`, `shell.qml`, `forynarch-window-layout.py`: placement,
  pairing and reversible arrangements.
- `forynarch-window-control.py`, `forynarch-window-switcher.sh`, generated bindings:
  focus and raise floating windows together.
- `windows.lua`, shortcut catalog/compiler and settings: native border resizing,
  edge alignment and configurable arrangement commands.
- Launcher/settings icons, Forynarch icon theme, `integrate-desktop.sh` and
  `licenses/Tabler-Icons.txt`: offline assets and license installation.

## Behavior and dependencies

The 44-pixel main panel includes the running-app icons inside its workspace
section. Its application section grows with the number of applications, bounded
by available screen width. Icon order survives focus/stacking changes. One icon
groups windows of the same application on the current workspace, including
minimized windows. There is no second application bar or count tooltip.

Hover opens a separate preview surface. Up to three native window captures are
shown at once, with paging for additional windows. Clicking a thumbnail focuses,
raises or restores that exact window. A single-window icon can also be clicked
directly. Captures refresh every 400 ms while the popup exists; closing it
destroys capture views and timers. The shared buffer backend initializes once
with a null capture source, without recording anything at idle. No screenshots
are stored on disk. Protected or unavailable capture sources have an honest
fallback; clicking still selects the window.

`Super+Ctrl+Space` opens **Arrange window**, also available in Settings → Desktop.
The picker offers halves and quarters, plus side-by-side and stacked pairs.
`Super+Ctrl+Arrow` places the active window in a corresponding half. These
bindings are editable in Settings → Shortcuts. `Super+Arrow` still focuses and
`Super+Shift+Arrow` still swaps. There are now 98 managed bindings.

Individual placements stay floating and can be freely moved or resized. Pairs
use Hyprland's native dwindle layout: dragging the shared border resizes both.
Other windows are minimized recoverably, because native tiles render below
floating windows; the picker explains this before pairing. The hotbar can
restore them individually. **Restore arrangement** recovers the original
floating flags and floating geometry, and restores windows parked by pairing.
Closed windows, reused addresses with different PIDs and windows moved to another
workspace are skipped. Previous native tiling hierarchy is not serialized.

Placement is triggered by the picker or snap shortcuts. Native edge snapping
aligns dragged floating edges; it does not automatically turn a drag to the
screen edge into a half-screen tile. Display scale, rotation, origin and reserved
panel space are included in placement calculations. Applications retain their
own minimum-size constraints. Workspace defaults for new windows remain separate
from explicit changes to open windows.

Verified API versions: Arch Quickshell 0.3.2 / Qt 6.12 and Hyprland 0.56.2.
No additional daemon, package or developer toolchain is introduced. Python is
the previously documented core runtime dependency, not an optional development
toolchain selection.

Application icons use the package's own desktop-entry artwork. Missing artwork
uses an application monogram instead of a shared grid icon. The shell explicitly
selects the Forynarch icon theme. Power/session actions use distinct SVGs adapted
from [Tabler Icons](https://github.com/tabler/tabler-icons), under its
[MIT license](../licenses/Tabler-Icons.txt); exact upstream revision, individual
sources and color changes are recorded in
[SOURCES.md](../assets/icons/Forynarch/SOURCES.md).
Existing third-party application artwork retains its own upstream licensing.
Settings use distinct section-specific Forynarch glyphs.

API references: [ScreencopyView](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/),
[HyprlandToplevel](https://quickshell.org/docs/v0.3.0/types/Quickshell.Hyprland/HyprlandToplevel/),
[PopupWindow](https://quickshell.org/docs/v0.3.0/types/Quickshell/PopupWindow/),
[icon-theme configuration](https://quickshell.org/docs/v0.3.0/guide/advanced/),
and [pinned native dispatchers](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp).

## Verification

Arch source tests: 143 passed without skips in the initial native run. Final
source checks, artifact boot and installed-target memory results are recorded
below when complete.

Native runtime verification already passed: horizontal and vertical pairs;
shared resize from 618/618 to 698/538 pixels without changing combined width;
restore of floating flags; UI half-screen placement; thumbnail selection and
raising; five-window pairing that parks three other windows, then restores all
five. Six new unit tests cover work-area geometry, a rotated/scaled display
with negative origin, invalid/duplicate targets and PID/workspace-safe restore.

VirtualBox's software renderer uses the supported shared-memory capture fallback
when no EGL render device can be selected. This is separate from QML load errors.
Hardware DMA capture, mixed-scale physical monitor changes, low-end hardware FPS
and battery use are not measured. Full repartitioning/installation is not rerun
for these desktop changes; the independent target rootfs is rebuilt and checked.

## Installed memory and ISO

The R4.3 installed core peaked at 1,246,883,840 bytes after five idle minutes,
with swap 0. R4.4 rebuilt the independent target archive and ISO; the exact ISO
passed cold UEFI boot, branding and desktop-shortcut checks. R4.4 installed RAM
has not been remeasured. See the [current build evidence](blue-hour-r44-review.md).
