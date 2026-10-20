# Floating snap and vertical split review

The automatic placement of other floating windows described below was superseded
by [selected-window snapping](windows-snap-behavior-review.md). Single-window
floating placement now leaves other applications unchanged.

## Intent and files

Keep floating placement independent instead of converting every snap into a
native tiling tree. Make upper/lower splitting explicit in the arrangement picker.

Changed `scripts/forynarch-window-layout.py`, `WindowLayoutPicker.qml`,
`SnapOverlay.qml`, the window layout unit/native fixtures, and
`docs/wiki/smart-window-layouts.md`.

## Behavior

Floating windows and Floating/Hybrid workspaces use geometry placement. Snap
partitions the remaining space without introducing native tiling constraints.
Moving or resizing a snapped float leaves neighboring windows independent.
Floating pairs touch only the two selected windows. Their restore snapshots
exclude unrelated windows. Native pairs keep all unpinned participants visible
and use the existing Dwindle root split rather than minimizing other windows.

The picker labels the vertical orientation **Top / bottom**. Floating corner
previews show the actual quarter rather than substituting a half for two windows.
Explicit **Tile open windows** remains available. No background service or new
package was added.

## Versions and verification

Tested in the disposable Arch Live QA VM with Hyprland 0.56.2, Quickshell 0.3.2
and three real Alacritty windows. The full suite ran 216 tests: OK, one skipped.
After the final snapshot filtering and grouped-window safeguards, all 12 targeted
window layout tests passed, including routing between floating/native layouts and
exclusion of unrelated windows from floating-pair restore snapshots.

Native fixture results:

- All eleven floating snap regions stayed floating, remained within the usable
  monitor area, and did not overlap immediately after placement. Independent
  resize did not change neighbors; moving a snapped window did not change its mode.
- Both floating pair orientations left the third window open and unchanged.
- All eleven native snap regions passed visibility, bounds and overlap checks.
  The upper-half split resized neighboring tiles through its shared divider.
- Native horizontal and vertical pairs passed shared-resize checks without
  minimizing the third window.
- Zero gaps, square corners, live reflow, reload persistence, explicit tile-all
  and floating activation checks passed.

Final QML loaded successfully in both QA and the user's Live VM, and Hyprland
reported no configuration errors. In the user's Floating workspace, two windows
identified by the prior snap snapshot as originally floating were restored to
floating while preserving their current bounds. PID/workspace checks excluded
unrelated or replaced windows.

## Limits and next verification

The native fixture used one virtual monitor and three real windows. Mathematical
partition tests cover up to twelve companion cells; application minimum sizes,
physical multi-monitor drags and long-running real hardware use remain untested.
Manual floating movement can intentionally overlap windows. Automatic propagation
of independent floating resizes is not imposed; choose native tiles for shared
dividers. No installed-system RAM benchmark or new ISO build was performed.
