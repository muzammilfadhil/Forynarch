# Smart layout and floating focus review

Follow-up: [smart snap and configurable geometry](smart-snap-geometry-review.md)
replaces the drag path with a shared multi-window tree and documents the later
gap/corner controls. This document records the earlier two-window fix.

## Intent and affected files

Fix independent half-screen snaps that could not resize together, floating
occlusion of selected native pairs, and hover-driven floating focus changes.
Implementation: `scripts/forynarch-window-layout.py`, `config/hypr/windows.lua`
and `config/quickshell/forynarch/WindowLayoutPicker.qml`. Tests:
`tests/test_window_layout.py` and `tests/fixtures/smart-layout-native.py`.

## Behavior

Complementary, unmodified half-screen snaps now become a native pair. Eligibility
checks PID, monitor, floating/fullscreen/pinned/grouped state and saved geometry;
manual movement or resizing prevents automatic pairing. Pairing minimizes all
other unpinned windows on the same monitor, including floating windows that the
previous implementation left above the pair. Other monitors are excluded.

Tile open windows arranges existing windows in native Dwindle without changing
the default mode for future windows. Snapshots record affected windows only;
state is saved after successful placement. Restore retains identity/workspace
checks. Dwindle shared resizing and split preservation are explicit. Mouse hover
no longer changes focus; clicks and explicit activation select windows. Existing
directional focus/swap shortcuts and drag/resize mouse bindings remain intact.

Pinned windows are intentional exceptions and remain independent. Quarter and
third placements are still independent floating regions, not linked grid cells.

## Verification

Runtime: Hyprland 0.56.2-4, Quickshell 0.3.2-1, VirtualBox guest utilities
7.2.20-1. Official Dwindle and input configuration references were checked before
editing options. The running user's VM accepted all options with no compositor
configuration errors: smart_resizing=true, preserve_split=true, follow_mouse=0,
float_switch_override_focus=0.

On the isolated Arch Live QA VM, **211 tests ran successfully, one skipped**. Regression
coverage rejects automatic pairing after manual movement/resizing, PID reuse,
monitor changes, pin/fullscreen/group changes, malformed slots or wrong regions.
Native tests used three separately identified terminals on an empty workspace,
then closed only those fixtures and returned to the previous workspace:

- Complementary half snaps became native tiles. Enlarging one side shrank its
  companion, both stayed in bounds, and the third floating window was minimized.
- The vertical pair retained its orientation while its divider resized both
  windows. Restoring brought back the floating geometry and minimized window.
- All three windows tiled without pairwise overlap, then restored. Explicit
  floating activation selected the requested window.

The live layout picker rendered the added button without QML type errors; its
Tile open windows button was clicked successfully. Existing VM software-renderer
SHM/portal/text-input warnings remain. Guest-control responses were temporarily
delayed during the native run; it eventually completed with exit code 0 and all
three native success markers.

The same source changes were applied to the running R47 user VM. Its existing
applications remained open. `git diff --check` passed. No package or daemon was
added. The previously built R4.8 ISO does not contain these later changes.

## Limits and next verification

Physical GPU, multiple displays, fractional scaling, grouped-window workflows
and applications with large hard minimum sizes still require hardware checks.
This is not a new installed-core RAM benchmark. Build a new ISO before testing
these changes from a fresh USB image.

## References

- [Hyprland Dwindle layout and resize behavior](https://wiki.hypr.land/0.55.0/Configuring/Layouts/Dwindle-Layout/)
- [Hyprland input configuration](https://wiki.hypr.land/Configuring/Basics/Variables/)
