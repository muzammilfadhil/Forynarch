# Smart snap and configurable window geometry

## Intent and affected files

Replace drag-to-top maximize with an actual top snap and choices, make edge
snapping account for other open windows, and expose adjustable spacing and
corner shape. The previous two-window-only fix did not satisfy this workflow.

Files: `config/hypr/auto-snap.lua`, `scripts/forynarch-window-layout.py`,
Quickshell's `shell.qml`, `SnapOverlay.qml`, `WindowLayoutPicker.qml`,
`WindowGeometry.qml`, `SettingsPanel.qml`, `SettingsCatalog.js`,
`scripts/forynarch-system.sh`, `scripts/system-settings-model.jq`,
`scripts/forynarch-window-mode.sh`, `scripts/integrate-desktop.sh`, and related
source/native tests. The wiki guide describes the user-facing behavior.

## Implementation and dependencies

Verified on Hyprland 0.56.2-4 and Quickshell 0.3.2-1. The official v0.56.2 Dwindle
implementation was checked for preselect, move-to-root and exact split ratios.
Smart snap inserts the dragged window into a native Dwindle tree with the other
visible, unpinned windows on the same monitor/workspace. It does not minimize
those participants. Half, quarter and third placements share native dividers;
the two remaining cells in a three-window layout adapt to their available area.
The workspace preference remains floating when it was floating before the snap.
Explicit pair commands retain their documented minimize/restore behavior.

The top edge offers five pass-through choices and defaults to Top. Maximize is
still available explicitly, but is no longer the top-edge default. Overlay
geometry reads the actual monitor reservation and saved spacing. It is loaded
only during a snap preview; its pointer mask does not consume the drag.

Settings > Desktop exposes integer windowGap 0–40, screenMargin 0–64 and
cornerRadius 0–40. Old preferences receive defaults. Invalid values are rejected
before compositor dispatch or persistence. Settings are applied live and stored
atomically through the existing settings backend. Pending UI changes are flushed
when the settings component closes. Fixed radius 14 was removed from floating
workspace rules so they inherit the chosen radius. Staging installs the updated
backend/model as well as the QML. No package or resident daemon was added.

The long settings page now has a visible scrollbar and exposes read-only scroll
metrics through the existing appearance IPC for QA.

## Verification

**214 source tests ran successfully, one skipped.** Coverage includes top-edge
choice routing with no automatic maximize, monitor transforms, idle drag-timer
lifecycle, zero-spacing region math, invalid geometry values, persistence and
migration of older preference files.

Native tests on an isolated Arch Live QA VM created three identified terminals
on an otherwise empty workspace with the floating preference. All eleven smart
positions passed: top, bottom, left, right, four corners and three thirds.
Every participant remained visible, tiled and within usable bounds with no
pairwise overlap. The floating workspace preference was unchanged. Resizing
the top cell resized other cells. Existing horizontal/vertical pair, restore
and tile-all tests also passed.

Live geometry tests set gap, margin and radius to zero on existing tiles, checked
screen-edge geometry, reloaded Hyprland, and verified the square radius persisted.
Nonzero spacing and radius 28 were then verified; test preferences were restored.

Actual input was also exercised: Super-drag to the top displayed the choice strip,
selected Top, and produced one top tile plus two bottom tiles. All three had
fullscreen=0. On a 1280 x 800 monitor with a 64-pixel reservation, their body
rectangles were `[15,79,1250,346]`, `[15,439,618,346]` and `[647,439,618,346]`.
The overlay's initial visibility binding loop was corrected and the repeat run
showed no such warning.

The Desktop page rendered all three sliders. Its scrollbar was dragged to reach
them. Setting all sliders to zero and immediately closing Settings saved all
three values; the compositor reported rounding=0, and a screenshot confirmed
square, touching tiles. Native reload tests verified persistence. Mouse-wheel
scrolling was not established by the host's injected wheel events; scrollbar
dragging was verified. Existing VM SHM, portal and Wayland text-input warnings
remain; no new QML type errors appeared in these interactions.

## Delivery and remaining limits

Source and the running R47 user VM have been updated; application windows were
kept open. User spacing values were not forced to zero. The previously built
R4.8 ISO does not contain these later changes; build a new ISO for USB testing.
`git diff --check` passes. No installed-core RAM benchmark is claimed here.

The initial incremental update of that older VM missed NotificationCenter and
the panel failed to load. Deploying the complete bundled QML dependency set and
notification helper repaired it. The final log confirmed Configuration Loaded;
a host-window screenshot confirmed the panel and existing terminal applications
were present. This was a live-update tooling failure, not a passing deployment.

Pinned windows remain independent and can intentionally cover tiles. Grouped
participants require ungrouping. A single window uses a floating region, corners
with two participants become halves, and a middle-third layout requires three
participants. Hardware/fractional-scale/multi-monitor, large minimum-size apps,
and larger window trees need further native coverage before release claims.

## References

- [Hyprland v0.56.2 Dwindle algorithm and layout messages](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.cpp)
- [Hyprland gap and decoration options](https://wiki.hypr.land/configuring/core/config-options/)
- [Qt ScrollView behavior](https://doc.qt.io/qt-6/qml-qtquick-controls-scrollview.html)
