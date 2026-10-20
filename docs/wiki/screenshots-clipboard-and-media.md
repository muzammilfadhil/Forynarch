# Screenshots, clipboard and music

## Screenshots

Print Screen captures the whole desktop. Super + Shift + S starts a region
selection: drag with the pointer, or press Escape to cancel. Open **Screenshots**
from the launcher for the same controls.

In **Settings → Screenshots & Clipboard**, choose the screenshot directory,
whether to save PNG files, and whether to copy images to the clipboard.
The default folder is the XDG Pictures directory's `Screenshots` subdirectory.
Disable file saving and leave clipboard copying enabled for clipboard-only use.
At least one destination must remain enabled. Cancelling a selection preserves
both the existing clipboard and saved files.

## Clipboard history

History is off by default. Enable it in **Screenshots & Clipboard**, then use
Super + Ctrl + V or launch **Clipboard History**. Super + V retains its existing
floating-window shortcut. All these bindings can be changed in Shortcuts.

Copy an entry to return it to the clipboard, then paste normally in the target
application. Delete removes an individual history entry. **Clear everything**
also clears the current clipboard and primary selection. History is local,
bounded to 50 text/PNG entries and 16 MiB total, with a 4 MiB per-entry limit.
Clipboard contents marked sensitive by their source are excluded; applications
that omit this flag can still expose passwords or other private text. Disable
history when recording copied content is inappropriate.

The database is `~/.local/state/forynarch/clipboard.sqlite3`; preferences are
`~/.config/forynarch/capture.json`, both private to the user. No history watcher
runs while history is disabled. Secure SQLite deletion does not promise physical
erasure from SSD snapshots or backups.

## Music widgets

In **Settings → Desktop**, enable Music and choose the classic or MacShell
player card. Select automatic player detection, Mudil Music, or a particular
running MPRIS player. Album artwork, lyrics and the Cava visualizer have separate
switches. Widget placement and presets remain available in Edit Widgets.

Lyrics are off by default. When enabled, the widget first uses lyrics supplied
by the player. Otherwise it sends the current title, artist, optional album and
duration to [LRCLIB](https://lrclib.net/) on track changes. Online results are not
guaranteed, and this lookup requires connectivity. Timed lyrics follow playback;
untimed lyrics can be scrolled. No online lyric requests run with lyrics or the
music widget disabled. The shell does not download a second audio stream.

## Mudil Music setup option

Mudil Music is an unchecked choice on the operating system installer's software
page. It is neither a core dependency nor an automatic first-login installation.
Its reviewed Arch package is bundled separately from the target rootfs. Selecting
it also resolves the native `mpv` and `libsecret` runtime requirements. It does
not select developer toolchains. The current optional-software workflow requires
an online installation for repository dependencies.

Linux MPRIS support uses `audio_service_mpris` 0.2.1. The player identifies as
Mudil Music; its playback metadata feeds the desktop widget. If no track is
playing, showing no lyrics is expected. The Linux build also falls back to its
application support directory when no Documents directory is available, while
preserving an existing Documents-based Hive store.

Community builders can omit the optional binary and still build the OS. That
disables the Mudil installer choice. To include a reviewed build, put the package
in ignored `out/optional/`, update `packages/local-applications.json` with its
version and SHA-256, and run `scripts/bundle-local-applications.py SOURCE BUNDLE`
on Arch. The bundler and installer verify the checksum, package identity and
allowed install paths. No private Mudil application state belongs in an ISO.

## Panel appearance

In **Settings > Panel**, select the bar and Control Center styles independently.
For example, keep the Forynarch bar and use the MacShell Control Center. Music
has its own style in Desktop settings. Forynarch remains the default.

MacShell offers the original four-column glass tiles or a single frosted panel,
with a muted blue material and the upstream glyphs. **Edit Controls** supports moving,
removing and adding controls; arrow keys reorder a focused tile and Delete
removes it. Reset restores the original order. Hardware-dependent controls are
disabled when unavailable. Screen recording controls are removed. Night Shift
needs the optional `hyprsunset` command, which is not installed automatically.

Click the bar's speaker button, or right-click Sound in the Control Center, to choose
default input/output devices and adjust per-application volume. The MacShell
audio view uses the same material. Control Center has its own two-slider button
in the bar. Changing volume preserves an application's
chosen output. The Forynarch style opens its existing Sound settings.

Panel settings also expose bar heights, screen margin, group padding, application
icon size and spacing, vertical offsets, label sizes, and window-preview spacing
and sizes. Values are bounded to protect the layout. Reset restores the defaults.
Application preview headers provide minimize/restore, maximize/restore, and close.
Right-side bar buttons keep accessibility labels without hover tooltips.

The optional Control Center captures one background frame while opening and
uses a bounded, eight-tap Liquid Glass shader. Closing it releases the capture.
Music cards use compositor blur behind their surface, not a stretched wallpaper
crop. Reduced motion and the existing visual-effects settings remain available.

The adapted player and glass source is credited in
[MacShell provenance](../../config/quickshell/forynarch/MACSHELL-SOURCES.md), with
the [retained MIT notice](../../licenses/MacShell-MIT.txt).

## Floating window minimization

Super + H minimizes the active window. Its process continues running and it
leaves the visible desktop. Alt + Tab includes minimized windows belonging to
the current workspace. Selecting one, or activating its application in the bar,
restores and focuses it. Floating dimensions are preserved. Windows belonging
to another workspace remain there. Super + V continues to toggle floating.
