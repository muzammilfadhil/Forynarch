# Create and share widget packs

Widget packs are ordinary UTF-8 JSON files. You can build your own cards without
installing a compiler, Node.js, Git or a development environment. The first format
supports text, clocks, memory/battery meters and dividers. Packs inherit the
desktop's navy glass surface, accent, scaling and layout editor.

## Import a pack

1. Open **Settings → Desktop → Community widget packs → Manage packs**, or use
   **Import / manage packs** in the widget layout editor.
2. Choose a JSON file, or enter its local path and choose **Review**.
3. Check the pack name, author, declared license and widget count.
4. Choose **Import pack**. Every imported widget starts switched off.
5. Enable the cards you want. Choose **Edit layout** to drag them, snap to the
   grid, or use the Left, Right and Balanced presets. Save the layout.

The **Workday example** button opens a bundled example for review. Its source is
[`examples/widget-packs/workday.json`](../../examples/widget-packs/workday.json)
in the repository, and `/usr/share/forynarch/widget-packs/workday.json` on Linux.

## A small pack

```json
{
  "schemaVersion": 1,
  "id": "my-desk",
  "name": "My desk",
  "author": "Your name",
  "license": "MIT",
  "description": "A clock and a personal reminder.",
  "widgets": [
    {
      "id": "clock",
      "name": "Desk clock",
      "height": 160,
      "items": [
        {"kind": "text", "text": "TODAY", "size": 10, "color": "accent"},
        {"kind": "clock", "format": "HH:mm", "size": 32},
        {"kind": "text", "text": "{date}", "color": "muted"},
        {"kind": "text", "text": "One task at a time.", "size": 12}
      ]
    }
  ]
}
```

Use a license you have permission to grant. The `license` field records the
author's declaration; Forynarch does not verify ownership or grant rights for you.
The bundled Workday JSON example is dedicated under CC0-1.0; this dedication
applies to that example, not the entire Forynarch repository.

## Format version 1

The required top-level fields are `schemaVersion` (integer `1`), `id`, `name`,
`author`, `license`, and `widgets`. `description` is optional. Unknown fields
are rejected. Pack and widget IDs start with a lowercase ASCII letter and use
lowercase letters, digits and hyphens, with at most 40 characters. Widget IDs
must be unique within a pack. Pack IDs must be unique in the installed catalog.

Each widget requires `id`, `name`, `height` and `items`. Cards are 224 logical
pixels wide; height is an integer from 80 to 320. Global Small/Medium/Large
scaling applies to the whole card. Leave at least 32 pixels for outer padding
and 10 pixels between items. Oversized content is clipped inside the card.

| Item kind | Fields | Behavior |
| --- | --- | --- |
| `text` | `text`; optional `size`, `color` | Plain text, up to three visible lines; supported tokens are substituted |
| `clock` | `format`; optional `size`, `color` | Qt date/time format, updated once per minute; formats containing seconds are rejected |
| `meter` | `source`: `memory` or `battery`; optional `label` | Label, value and thin meter; missing batteries show Not available |
| `divider` | No additional fields | A quiet horizontal separator |

Font size is an integer from 10 to 32 (default 13). Color is `accent`, `text`,
`muted`, or `#RRGGBB`. Clock formats include `HH:mm`, `hh:mm AP`, `dddd`, and
`dd MMM yyyy`. Text is rendered as plain text; HTML and JavaScript are not
interpreted.

Text tokens: `{time}`, `{date}`, `{user}`, `{memoryUsed}`, `{memoryTotal}`,
`{batteryPercent}`, `{trackTitle}`, and `{trackArtist}`. Memory values use decimal
GB and `MemTotal - MemAvailable`. Resource collection runs every 30 seconds only
when a visible built-in or custom widget needs it. Media data reuses the existing
MPRIS connection. Disabled cards create no widget window or resource timer.

## Export, update and remove

**Export** saves the pack definition, including its author and license. It does
not export usernames, account credentials, media history, enabled switches or
monitor positions. **Remove** asks for confirmation, unloads the pack and removes
its registry JSON. Exported files remain untouched. To replace a pack using the
same ID, export a backup, remove the installed version, then review the new file.

Packs are stored in `$XDG_DATA_HOME/forynarch/widget-packs`, normally
`~/.local/share/forynarch/widget-packs`. Layout positions and enabled switches
remain in `~/.local/state/forynarch/appearance.json`. Do not edit that state file
while the shell is running; use the editor to avoid overwriting changes.

The registry is read on shell startup and after pack operations, with no watcher
daemon. After editing an installed JSON file manually, restart the shell or
remove/reimport the pack. Keep a source copy outside the registry.

## Command line

```sh
forynarch-widget-packs inspect ./my-desk.json
forynarch-widget-packs import ./my-desk.json
forynarch-widget-packs list
forynarch-widget-packs export my-desk ./my-desk-shared.json
forynarch-widget-packs remove my-desk
```

These operate on your user directory and do not require sudo. The UI pins an
inspection digest, so a changed file must be reviewed again before import.
Export refuses existing files unless `--replace` is explicitly supplied.

## Limits and extension points

Files are limited to 64 KiB, 8 widgets per pack and 8 items per widget. The catalog
accepts at most 8 packs and 24 custom widgets. Imported packs cannot contain QML,
shell commands, arbitrary file readers, plugins, external fonts, remote images
or network endpoints. Archive extraction and automatic downloads are not used.
The format is deliberately data-only; it is not an arbitrary-code plugin API.

To add a new item type, contribute its validation to
`scripts/forynarch-widget-packs.py`, rendering to `CustomWidget.qml`, meaningful
tests and format documentation. Full QML widgets can be developed in a source
checkout; they require code review and are not accepted by the JSON importer.
Keep new defaults off until installed-target memory and hardware tests pass.

## Recode the built-in widgets in QML

Choose **Edit widget source** in the pack manager. It opens
`~/.local/share/forynarch/widget-sources` in File Manager. These files are links to
your active, writable `~/.config/quickshell/forynarch` sources, not a read-only
system copy. `forynarch-widget-packs sources` also prepares the folder. No sudo
is needed. Use any editor you choose; an IDE is not installed automatically.

Back up your configuration first. Quickshell reloads changed sources. Local
QML/JavaScript can execute code as your account, so review third-party code
before copying it into active configuration. Local source editing is unrestricted;
the JSON importer does not automatically execute downloaded QML.

| File | What to change |
| --- | --- |
| `DesktopWidgets.qml` | Built-in clock, calendar, greeting and music cards; component registry |
| `ExtraWidget.qml` | Digital clock, focus, memory, battery, quick launch and keyboard guide |
| `WidgetPacks.js` | Widget names and preset memberships |
| `WidgetLayout.js` | Stable IDs, logical heights and layout geometry |
| `WidgetSurface.qml` | Placement, scaling, grid dragging and keyboard movement |
| `WidgetEditor.qml` | Editing toolbar and presets |
| `CustomWidget.qml` | Rendering for imported data-only cards |
| `ClockFace.qml`, `CavaMeter.qml` | Clock drawing and music spectrum presentation |
| `GlassCard.qml`, `ActionButton.qml`, `Icon.qml` | Shared visuals; changes affect other desktop surfaces too |
| `shell.qml` | Persistent state and shared services; advanced edits can affect the entire shell |

To add a fully custom QML card:

1. Add a stable ID and label to `WidgetPacks.js`'s `widgets` array.
2. Append the same ID to `WidgetLayout.js`'s `keys`, and its height to `heights`.
   Keep existing IDs in order.
3. Define a `Component` in `DesktopWidgets.qml` and append it to `cards` in the
   corresponding `keys` order. For example:

```qml
Component {
    id: reminderCard
    GlassCard {
        width: 224; height: 120
        glass: controller.glass; frost: controller.frost
        Text {
            anchors.fill: parent; anchors.margins: 16
            text: "One task at a time."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: controller.accent
            font.pixelSize: 18
        }
    }
}
```

4. Reload if automatic reload is disabled. The new switch appears in Settings
   and the editor, initially disabled. Enable and place it there.

Stable IDs preserve saved positions. Reuse `controller.now`, `controller.player`
and `controller.widgetMetrics` instead of duplicate daemons. Stop timers/processes
when hidden and respect `controller.motion`. Test new cards separately from the
installed-core RAM gate. Share actual files, changes and licenses, not these
source links: their targets are specific to your user directory.
