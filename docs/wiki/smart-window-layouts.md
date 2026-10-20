# Smart window layouts

Press **Super + Ctrl + Space** to open **Arrange window**.

- **Floating / Hybrid:** snapping keeps windows floating. Drag a snapped window
  away or resize it independently; it does not become a native tile. Halves,
  corners and thirds move only the selected window. Other applications keep
  their position, size and mode; empty space remains empty until you choose
  another window. Placing windows in complementary regions does not auto-pair them.
- **Side by side / Top / bottom:** choose another window to split the screen.
  Floating pairs remain independent and leave other windows untouched.
  For tiled windows, the selected window occupies the left or upper half and
  other participants share the remaining area with draggable dividers.
- **Tiling:** position buttons arrange tiled windows in a native Dwindle tree.
  **Top half** and **Bottom half** create vertical splits; drag the horizontal
  divider to resize them. Other unpinned participants remain visible.
- **Tile open windows** explicitly converts the current unpinned windows into
  native tiles. Newly opened windows still follow the saved workspace mode.
- Drag a floating window to the top edge for the choice strip: Left, Top left,
  Top, Top right and Right. Release over the desired choice. Top means the
  upper half; maximize remains a separate window action.
- **Restore arrangement** restores saved geometry and window modes. Closed
  windows or windows moved to another workspace are not replaced or pulled back.

Clicking a floating window or activating it from the hotbar raises it. Moving
the pointer across another window does not change keyboard focus. A floating
window can overlap other windows after manual movement or resizing; snapping
does not impose a permanent layout constraint. Explicitly tiled windows share
resize dividers instead.

Pinned windows remain independent. Ungroup windows before arranging them.
These changes use the existing on-demand helper and compositor events; no new
resident process or idle resize polling loop is required.

## Gaps and corner shape

Open **Settings > Desktop** and scroll to the window controls:

| Control | Range | Behavior |
| --- | --- | --- |
| Window gap | 0–40 logical pixels per edge | Padding at shared dividers; 0 removes empty gaps |
| Screen margin | 0–64 logical pixels | Space from the usable screen boundary, respecting reserved panels |
| Window corners | 0–40 logical pixels | 0 is square; larger radii make compositor corners rounder |

The panel reserves its own height and outer offset only. There is no fixed extra
gap below it: Screen margin controls the distance from the panel's reserved edge.

Changes apply to open windows and persist across compositor reloads. Empty
spacing of 0 retains the thin window borders; they meet without wallpaper
between them. Application-drawn internal corners remain under the app's own
control. Floating workspace rules inherit the global radius rather than forcing
a fixed radius.

Preferences live in `~/.config/forynarch/system.json`; the validated configuration
is generated in `~/.config/hypr/system-settings.lua`. The command-line equivalent:

```sh
forynarch-system set windowGap 0
forynarch-system set screenMargin 0
forynarch-system set cornerRadius 0
```
