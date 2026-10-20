# Workspace controls, shortcuts and motion review

## 16 October follow-up: one panel

The user removed the requirement for a separate application navigator. This
supersedes the navigator descriptions in the R3.1 report below.
`DesktopPanel.qml` now reserves one 44-pixel row / 56-pixel exclusive zone in
every mode. `RunningApplications.qml` replaces `WindowNavigator.qml` with static,
grouped application icons in existing panel space. Active and minimized marks
reflect window state; hover gives the application name and window count.
No window action buttons, additional process, polling timer or package is added.
Window shortcuts and native decorations remain available.

Verified on the running R3.1 Arch / Hyprland 0.56.2 VM: Quickshell loaded with
no QML errors; floating ? hybrid ? floating each exposed exactly one panel layer
of height 44; five windows were grouped into two applications. Minimized state
was inspected visually, then restored using the existing window-control helper.
`git diff --check` passed. Native hardware, overflow at high application counts,
and a new installed-target RAM benchmark were not tested for this change.
Source and the running VM are updated; the R3.1 ISO below has not been rebuilt.


15 October 2026. This implements the user's workspace controls request and the
later clarification that Super+Arrow changes focus and Shift adds swapping.

## Intent and affected files

- `scripts/forynarch-window-control.py`: workspace-scoped window actions,
  recoverable minimize, and whole-workspace floating with state restoration.
- `DesktopPanel.qml`, `WindowNavigator.qml`, `shell.qml`: application navigator
  and working controls in floating workspaces, updated through compositor events.
- `scripts/hotkeys.py`, generated bindings/catalog/guides,
  `scripts/forynarch-shortcut-config.py`, `ShortcutEditor.qml`, `SettingsPanel.qml`,
  `ExtraWidget.qml`: editable system shortcuts and matching displayed labels.
- `config/hypr/motion.lua`, `scripts/automation_support.py`, shell appearance
  restoration: visible finite animations and restoration after config reload.
- GTK settings/schema override, `scripts/integrate-desktop.sh`, tests and docs:
  packaging, native decoration defaults and verification.

## Behavior and dependencies

Hyprland 0.56.2, Quickshell and Qt 6.12 were exercised in Arch VirtualBox guests.
The helpers use the existing Python runtime, already required transitively by
the tested core. They add no developer SDK, package group or background daemon.
The author-time shortcut compiler is not installed in the target.

Super+L explicitly floats existing windows in the current workspace. Previously
tiled windows use the workspace size preset with staggered positions. Existing
manual floating windows retain their geometry. Toggling back restores the
previous mode and floating flags for surviving address/PID pairs. New windows
follow the selected mode; this is independent of Super+V's per-window override.

Minimize moves a window to a private special workspace and remembers its origin.
The application stays running. Clicking its application tab restores it;
Super+Ctrl+Shift+M restores the last minimized window in the current workspace.
Close uses a normal application close request, preserving unsaved-work prompts.
The shared navigator supplies minimize/maximize/fullscreen/close controls for
applications with or without native title bars. Native GTK decoration defaults
omit the minimize request that this compositor does not implement.

The packaged Hyprland example also suppresses maximize requests from every
application. `config/hypr/windows.lua` disables that named rule. Reopen an
application that inherited the old suppression flag; the shared panel's
controls also work with already open windows. Native File Manager maximize,
restore and close were verified through its own decoration buttons.

Settings → Shortcuts covers 93 shipped system bindings, including aliases,
workspace slots, media controls and mouse drag bindings. Users can assign,
disable, reset one action or restore defaults. Canonical modifier/key names
make equivalent chords collide. Registered additional bindings are checked;
changes are rejected if applying them would overwrite an external binding.
Application-internal shortcuts remain application settings.

Changes are applied in the active session, with rollback after compositor or
file-write failures. Generated user Lua references current factory actions;
updates can correct actions while preserving chosen keys. User state is stored
in `~/.config/forynarch/shortcuts.json` and `~/.config/hypr/bindings-user.lua`.

Reload previously reset the animation master switch without restoring the
profile. Reload now restores motion and the shell's glass settings. First-run
defaults are applied even when no appearance preference file exists. Reduced
motion and opaque mode survive reload as well. Window scale/fade, geometry
changes and workspace slides use native compositor animation; shell motion blur
remains the existing finite panel effect. No claim is made of a cross-application
motion blur implementation or a pixel-identical macOS animation.

## Tests run

- Arch: **137 unit/behavior tests passed**, no skips, **4.532 seconds**.
- Bash syntax and ShellCheck passed for shipped helpers, runners and fixtures.
- Archiso 91 profile policy: eight entries checked, five files changed; second
  application changed zero files. Explicit copy-to-RAM boot choices preserved.
- Actual Hyprland session: whole-workspace floating and return, manual floating
  flag preservation, preset geometry, minimize/restore, restore-last,
  maximize/fullscreen round trips, and normal close passed.
- Actual shortcut configuration: managed/external collision rejection,
  immediate remap, persistence across reload, disable and reset passed. The GUI also rejected a real
  collision and saved a valid remap; its physical virtual-keyboard chord opened
  the launcher. Defaults were restored afterwards.
- Physical virtual-keyboard checks passed in tiling and floating modes:
  Super+Right changed focus without moving windows; Super+Shift+Left swapped
  positions and preserved the active client.
- Focus also passed with newly opened floating windows stacked at identical
  starting positions.
- Motion on/off and glass on/off survived native config reloads. Reduced motion
  remained off. Native configuration reported no parse errors.
- Source tests cover failed compositor application, failed JSON persistence,
  input injection, canonical collisions and current factory action resolution.

Fixtures: `tests/fixtures/workspace-controls-flow.py` and
`tests/fixtures/arrow-motion-flow.py`. Run in a disposable Arch Hyprland session;
the arrow fixture has phases around actual keyboard input. They open their own
test windows and should not run against a working user's active workspace.

## Final artifact and memory

`out/iso/forynarch-2026.10.15-blue-hour-r3.1.iso`, **3,921,051,648 bytes**:

```text
629dfc79eef60ca451b7a6c77f943b65e219e4e1e9232414472152a1454930ad
```

Builder and Windows checksums match. A fresh UEFI VirtualBox guest with 3 GiB,
two CPUs and no hard disk cold-booted the image. Packaged helper, shell and
window-module hashes matched source. First-run motion and compositor blur were
enabled without any appearance preference file. All 93 system shortcuts loaded
without collisions; save/reload/reset passed. The floating navigator loaded with
File Manager, and its native maximize button worked in the packaged image.

The separate **installed core** QA guest used 4 GiB and two CPUs. After five idle
minutes, six samples eight seconds apart recorded `MemTotal - MemAvailable`:

```text
1265442816
1269764096
1269764096
1269891072
1274339328
1274093568
```

Peak: **1,274,339,328 bytes**, below the **3,000,000,000-byte** gate. Swap used:
**0 bytes** in every sample. The active graphical VT had no application windows;
four default widgets, the floating navigator, motion and compositor blur were
enabled. Native option queries confirmed both motion and blur were true.
Helper, profile, shell and window-module hashes matched final source. This is
an installed-target measurement; Live boot evidence is separate.

Local evidence is retained under ignored `out/virtualbox/`, including
`r3-installed-metrics.log`, `r3.1-final-idle.png`, `r3.1-cold-final.png`, and the
shortcut validation/edit screenshots. No VM image or log is source-controlled.

## Remaining verification

Animation timing and GPU power use need physical low-end laptop testing.
VirtualBox software rendering cannot establish hardware frame pacing or battery
life. A short early fullscreen QA run exceeded its original ten-second test
deadline under VM load; repeated complete runs passed with the fixture's
thirty-second per-command deadline. Runtime compositor calls retain timeouts.
These acceptance runs used one virtual monitor; physical multi-monitor focus,
hotplug and mixed-scale acceptance remain separate checks.

The full installer partitioning flow was not repeated for these desktop changes.
The independent target archive is regenerated and validated; earlier installation
QA remains a separate record. No physical disk, account credential or Windows
security setting was changed by this work.

References: [pinned Hyprland dispatchers](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp),
[official dispatcher documentation](https://wiki.hypr.land/configuring/core/dispatchers/).
