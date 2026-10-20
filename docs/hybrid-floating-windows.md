# Hybrid and floating windows

Open **Settings → Desktop → Workspace mode**. Each workspace keeps its own mode.

- **Hybrid** tiles main applications and opens File Manager, audio controls,
  network connection editor, Bluetooth Manager and Partition Manager floating.
- **Floating** opens new windows as overlapping, centered windows with rounded
  corners. Compact, Comfortable and Spacious presets set their initial size.
- Tiling, Master and Scrolling remain available for structured work.

Choose **Floating window size** to set the starting size for this workspace.
The presets occupy approximately 60%, 72% and 86% of the monitor dimensions.
Applications may impose their own size constraints. Changing the preset does
not resize windows that are already open. **Float and resize active window**
explicitly applies the preset to the last focused application, using usable
monitor space and centering the result.

Resize floating windows by dragging their border or with **Super + right drag**.
Move them with **Super + left drag**. **Super + V** keeps the existing per-window
float/tile toggle. Manual adjustments are independent of the workspace default.
The **Also float or tile the open windows** option explicitly changes existing
windows; leave it unchecked to preserve them.

GTK applications put close/maximize controls on the left where their
client decorations support it. File Manager enables its native client
decorations by default; **Settings → Files → Window controls** can change this.
Reopen File Manager to apply that preference. The blue identity remains. Applications without
a title bar, including Foot, still use compositor movement and resize gestures.
The packaged example's global maximize-suppression rule is disabled. Windows
opened before that change may need reopening to accept their native maximize
button. The compositor shortcuts also work with existing windows.
The main panel keeps a fixed 44-pixel height in every workspace mode. Running
applications sit inside its workspace section; there is no second application
bar. The strip grows with application count, keeps a stable icon order, and
scrolls when space is limited. Hover shows actual window previews; click a
thumbnail to focus, raise or restore that window. There are no count tooltips.
Capture views exist only while the preview popup is open.

**Super + Ctrl + Space** opens **Arrange window**. Place a floating window in a
half or quarter, or choose another window for a side-by-side / stacked pair.
**Super + Ctrl + Arrow** places a floating window in the corresponding half.
Pairs use native tiling so the shared border resizes both windows. Other windows
are minimized recoverably and remain available in the hotbar; **Restore
arrangement** brings them back and restores floating flags and floating geometry.
See [the implementation review](hotbar-snap-icons-review.md) for scope, tests and
native tiling/edge-alignment distinctions.

Minimize uses a private special workspace because Hyprland 0.56.2 does not
handle GTK's native minimize request. No compositor plugin is installed.

**Super + L** toggles all windows in the current workspace into floating mode.
Previously tiled windows use the selected size preset and staggered positions.
Existing manual floating windows keep their geometry. Press it again to restore
the previous mode and each surviving window's previous floating state. If no
previous mode was recorded, it returns to Hybrid. **Super + V** remains an
independent per-window toggle. **Super + Ctrl + M** minimizes; add Shift to restore
the most recently minimized application in the current workspace.

**Super + Arrow** changes focus without moving windows. **Super + Shift + Arrow**
swaps their positions. This supersedes the earlier Super+Arrow swap mapping.

Open **Settings → Shortcuts** to edit, disable or reset any shipped system
binding. Conflicts with other system actions and additional active Hyprland
bindings are checked before writing. Application-specific shortcuts belong to
the application's own preferences. Overrides live in
`~/.config/forynarch/shortcuts.json`; the generated Lua references the current
factory actions, so an OS update can correct an action without losing the
user's chosen key.

The motion profile is restored after configuration reloads. Reduced motion
remains respected. Window opening uses a 90% scale with fade; closing uses 94%;
workspace changes slide and maximize/restore uses native geometry animation.
These finite compositor animations add no background animation process.

## Implementation and validation

Hyprland 0.56.2 rules set initial floating geometry and utility classification.
The size/center/float rules are static initial-state rules, so they do not
continuously force a user's manual geometry. Native border resize and mouse
bindings are loaded from `config/hypr/windows.lua`; there is no new daemon.
State is stored per workspace in `window-modes.json` and `window-sizes.json`.
The module is loaded by the generated Hyprland adapter and shipped by both
target and Live integration.

The native `tests/run-window-mode-flow.sh` fixture passes on Hyprland 0.56.2:
new utility/main windows follow Hybrid policy; new floating windows follow the
size preset; changing a preset preserves existing sizes; explicit fit changes
geometry; manual overrides and other layouts remain usable. The fixture also
keeps the 15-second lock-deadlock timeout. An idempotency issue found during this
test was fixed by using `on`/`off` for float actions instead of `set`/`unset`.

The native popup-focus fixture passes with the updated Settings UI. Arch source
tests: **129 passed in 3.830 seconds**, no skips; Bash syntax, ShellCheck and
Archiso boot-policy gates passed. The running installed QA VM received the same
helper and UI source, with an empty `hyprctl configerrors` result and a matching
helper SHA-256. Its current workspace was set to Hybrid without applying the
policy to already open windows.

The earlier R1 memory measurement remains R1 evidence. This update adds native
rules, event-driven helpers and controls rather than an idle service; a fresh
installed-memory benchmark of this exact revision has not yet been run.
Rotated/multiple physical monitors, pointer border dragging on real hardware
and application-specific title-bar consistency remain hardware checks.

R2 ISO cold boot also passed in a fresh UEFI VM. The actual packaged File
Manager opened floating at the Comfortable geometry with native controls;
Settings displayed the new mode and size choices, and both packaged helper
hashes matched source. See the [R2 build record](blue-hour-r2-build.md).

That boot caught a GTK default conflict: the schema default overrode the
per-toolkit decoration layout and initially showed only a right-side close
button. `config/glib-2.0/90_forynarch.gschema.override` now declares the same
left-side control layout. Strict schema compilation, a fresh GSettings default
read and a restarted native File Manager verified three controls on the left.
The corrected image is published separately as R2.1.

Native File Manager client decorations were also verified on the separate Live
QA VM, including left-side controls. Existing File Manager windows may retain
their old decoration until reopened. Application-specific minimize behavior is
not guaranteed by changing the GTK layout; the native compositor still owns it.

Syntax references: [official window rules](https://wiki.hypr.land/configuring/core/rules/window-rules/)
and the [pinned dispatcher implementation](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp).
File Manager CSD preference: [upstream Thunar implementation](https://github.com/xfce-mirror/thunar/blob/master/thunar/thunar-preferences.c).
