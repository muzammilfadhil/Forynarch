# Selected-window snapping

## Reference and scope

Microsoft's [Snap Your Windows documentation](https://support.microsoft.com/en-us/windows/experience/snap-your-windows)
describes placing the chosen window first and selecting another window through
Snap Assist to fill remaining space. Suggested windows are not an instruction
to automatically move every open application into the layout.

Forynarch's floating/hybrid snap now follows that selection rule. This change
does not claim complete Windows Snap Assist, thumbnail suggestions, or Snap Group
parity. The existing explicit window picker is the way to choose a companion.
Native tiling mode continues to use a shared tree when explicitly arranging tiles.

## Changes

- `scripts/forynarch-window-layout.py`: single floating snap touches only the
  selected window. Neighboring windows keep their position, size, mode and
  workspace. Complementary direct placements no longer implicitly create pairs.
  Explicit two-window pairing remains available. Restore snapshots include only
  participants actually arranged; the new snapshot schema avoids carrying old
  automatic-fill snapshots into a new single-window operation.
- `config/quickshell/forynarch/WindowLayoutPicker.qml`: labels single-window
  positioning clearly and explains that choosing another window is optional.
- `tests/test_window_layout.py` and `tests/fixtures/smart-layout-native.py`:
  verify selected-only placement, snapshot scope, complementary placement and
  existing explicit-pair/native-layout behavior.
- `docs/wiki/smart-window-layouts.md`: documents the updated behavior.

## Verification

The Arch Live QA VM ran the full source suite: 217 tests, OK, one skipped.
Native single-window checks compare unselected windows' actual geometry,
floating state, workspace and fullscreen state before and after each placement.
The native fixture also exercises independent move/resize, explicit pairs and
the retained native tiling geometry checks.

All eleven selected-window positions passed with unselected applications
unchanged. Complementary placement, both explicit floating pair orientations,
all eleven native layout positions, native shared resize, zero-spacing/reload
checks and tile-all/restore checks passed. The updated helper and picker are
active in the user's running Floating-mode Live VM. Quickshell reported
`Configuration Loaded`; Hyprland reported no configuration errors.

No daemon, package or compositor Lua syntax was added. Versions remain Hyprland
0.56.2 and Quickshell 0.3.2. This work does not include a new ISO build, an
installed-system RAM benchmark or a physical multi-monitor test.
