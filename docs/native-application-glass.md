# Native application glass and complete controls

## Intent and source

Complete the native appearance beyond the file-manager toolbar: Trash actions,
dialog titles/buttons, entries, selection, menus and application backgrounds.
Expose glass backgrounds in Appearance and make Settings discoverable as an app.

Affected source: GTK 3/4 palettes and styles, Foot defaults,
`forynarch-application-theme.sh`, `forynarch-settings.sh`, desktop entries,
Quickshell appearance state/settings, target/Live helper wiring and two helper
tests. No new package or background daemon was added.

## Behavior

**Appearance → Application backgrounds** controls native glass independently of
the shell surfaces, under the main Glass surfaces switch. Background opacity
presets are Dense (92%), Balanced (84%) and Clear (76%). Text and controls stay
opaque. The existing Hyprland background blur supplies blur behind transparent
native windows; whole-window opacity is not reduced.

GTK palette files are generated atomically for GTK 3 and GTK 4. Foot's existing
dark color section receives background alpha while retaining its other settings.
Opaque mode restores solid backgrounds and Foot alpha 1.0. Identical palettes
are not rewritten. Invalid input is rejected before any file writes. Appearance
JSON type-checks and persists the new settings. Application palettes are applied
when preferences load or change; there is no idle polling process.

GTK applications and Foot load these changes when their processes restart.
Opening another Thunar window while its old process is still running can retain
the old theme. Finish file operations and close/restart that process before
expecting the new style. The preview does not forcibly close user applications.

Trash uses navy infobar content/action areas with readable enabled and disabled
buttons. Confirmation dialogs have navy title bars and styled action buttons.
The native Restore/Empty functions and confirmation remain unchanged.

Forynarch Settings has a desktop entry and keywords for glass/blur/appearance.
This Computer gains files/drives/storage/Windows keywords. Both can be launched
from Super+Space. Settings opens the existing Glass desktop's appearance panel;
the classic session fallback displays an explanation if that panel is unavailable.

## Versions and exact checks

Existing Live environment: GTK 3.24, Thunar 4.20.10-1, Foot 1.28.0,
Quickshell 0.3.2-1 and Hyprland 0.56.2-4. GTK node/state/rgba/import syntax was
checked against official documentation. Foot alpha syntax was checked against
its installed `foot.ini(5)` manual; `foot --check-config` exited 0.

- Windows Check: exit 0, 64 tests in 4.055s, 50 passed and 14 Linux-only
  storage tests skipped. All shell syntax checks and pipeline plan passed.
- Arch Live: 64 tests in 3.912s, OK. Native ShellCheck 0.11.0 reported no findings.
- Native Thunar rendered actual translucent backgrounds over the wallpaper.
  GTK 3 loaded the final styles without CSS parsing warnings.
- Trash rendering was tested with one self-created 34-byte fixture in an
  isolated XDG data directory and D-Bus session. Restore selection, Empty Trash
  and the confirmation dialog were inspected. Confirmation was canceled;
  the user's real Trash was not emptied.
- Searching `glass` returned Forynarch Settings; Enter opened Appearance.
  Searching `storage` returned This Computer. Launcher idle motion/layer flags
  remained false.
- Final Quickshell cold load succeeded and retained applicationGlass=true,
  applicationOpacity=84 and the user's existing panel/motion preferences.
- Application backgrounds off generated the opaque palette and Foot alpha 1.0.
  On at Clear generated rgba alpha 0.76 and Foot alpha 0.76. Balanced 84% was
  restored. Other existing appearance preferences were preserved.
- Short whole-guest RAM check: six samples at nominal five-second intervals,
  peak **1,583,620,096 bytes (1.584 GB decimal)**, swap 0, collector exit 0.
  Metric is `MemTotal - MemAvailable`. This includes retained user apps and
  private preview services; it is not a controlled installed-target idle test.
  User app state differs from earlier snapshots, so this is not a before/after
  performance comparison. Raw record: `out/virtualbox/native-glass-memory.txt`.

Runtime screenshots are in ignored `out/virtualbox`: `native-glass-files.png`,
`native-glass-trash.png`, `native-glass-trash-dialog.png`,
`native-glass-settings.png` and `native-glass-app-search.png`.

## Limits and next verification

GTK 4 styles are supplied but no GTK 4 application was rendered in this check.
Third-party Qt, Electron and toolkit-specific applications may retain their
own backgrounds and controls. This is not a claim of universal application
theming. Foot configuration parsed successfully; hardware rendering, frame
pacing, battery cost and long-duration application leak checks remain pending.

The existing ISO has not been rebuilt. Next: recover the builder, create the
updated Glass profile and verify a fresh boot, native application restarts,
GTK 4 rendering and installed-target memory on supported hardware.

References: [GTK CSS](https://docs.gtk.org/gtk3/css-overview.html),
[GtkInfoBar nodes](https://docs.gtk.org/gtk3/class.InfoBar.html),
[Thunar native styling](https://docs.xfce.org/xfce/thunar/hidden-settings)
and the installed Foot 1.28.0 `foot.ini(5)` manual.
