# R5.8.8 — Titlebar repaint and app exceptions

Apply after R5.8.7. This patch changes the native Hyprbars repaint region and
adds Settings > Desktop > Window controls. It does not install packages or
build an ISO. Its binary is pinned to the installed Hyprland 0.56.2-4 ABI.

## Install

Copy the archive and checksum to Forynarch, then run as the desktop user:

```sh
sha256sum --check forynarch-r5.8.8.tar.gz.sha256
tar -xzf forynarch-r5.8.8.tar.gz
cd forynarch-r5.8.8
bash apply.sh --check
bash apply.sh --apply
```

**Sign out and back in.** A configuration reload applies exception rules but
does not replace an already loaded plugin. The repaint correction requires
the new native plugin in a fresh desktop session.

## Repaint correction

In the reviewed upstream source, the paint scissor extends below the assigned
titlebar rectangle by three times the corner radius and applies the floating
offset. The damage function used only the assigned rectangle; the render-pass
bounding box used a fixed 10-pixel expansion. These regions can disagree as a
window moves, resizes or changes its corner radius.

The downstream patch makes the pass bounds follow that painted region, including
the floating offset, corner extension and a small edge allowance. Repaint marks
both previous and current regions, and erases the old bar on hide or removal.
It does not enable permanent full-monitor redraw or disable window animations.
The source change is reproducible through `scripts/patch-titlebar-damage.py`.

Source: [pinned paint/damage code](https://github.com/hyprwm/hyprland-plugins/blob/7644cecdb947060682891a0db2a0cdc5c0b9e704/hyprbars/barDeco.cpp)
and [render-pass bounds](https://github.com/hyprwm/hyprland-plugins/blob/7644cecdb947060682891a0db2a0cdc5c0b9e704/hyprbars/BarPassElement.cpp).
This addresses the identified bounds mismatch. Other graphics-driver artifacts
still require a recording and hardware-specific reproduction if they persist.

## App controls

Common app exceptions cover exact classes for Chrome/Chromium, Firefox/Zen/
LibreWolf, Brave, Vivaldi, Discord variants, Vesktop, Steam, Mudil Music, File
Manager and an explicit list of GNOME headerbar apps. Steam games and frameless
Forynarch web apps keep compositor controls. There is no blanket Electron,
Chrome-prefix or KDE exclusion. Applications with traditional menu bars still
need window controls; a menu bar alone is not a reason to exclude an app.

This is an editable default catalog, not a claim that every client exposes
reliable automatic CSD detection. Browser and Electron titlebar preferences
vary. For example, [Vivaldi supports both its own and OS window controls](https://help.vivaldi.com/desktop/appearance-customization/browser-appearance-customization-on-desktop/),
and [Vesktop has configurable window behavior](https://github.com/Vencord/Vesktop).
If an app's own controls are disabled, turn off App controls for that app to
restore Forynarch's floating titlebar.

Settings provides:

- A global Forynarch titlebar switch and a common-exceptions switch.
- Refreshable running apps with an App controls switch for each exact class.
- Manual exact-class exceptions, including apps not currently open.
- Saved overrides with Remove to return an app to its default policy.

Rules apply to existing and new floating windows without changing their
workspace mode or manual floating/tiling choice. Tiled windows remain outside
this titlebar policy. No resident helper or scanning timer is added.

Configuration and commands:

```sh
forynarch-titlebars status
forynarch-titlebars except discord true   # use Discord controls
forynarch-titlebars except discord false  # use Forynarch floating controls
forynarch-titlebars forget discord        # restore the default policy
```

Preferences: `~/.config/forynarch/titlebars.json`.
Generated rules: `~/.config/hypr/titlebar-rules.lua`.
Catalog: `/usr/share/forynarch/titlebar-defaults.json`.
The generated catalog Lua is updated from source with
`python scripts/forynarch-titlebars.py render-defaults`.

## Verification and restore

Exact executed checks and remaining hardware limits are recorded in
`tests/latest-results.md`. Target checks are native plugin loading, movement
and resize, empty configuration errors, live exception changes, persistence,
and settings input/error states. No new installed idle-RAM result is claimed.

Executed: eight policy tests passed on Windows and Arch; the R5.8.7-to-R5.8.8
live upgrade and fresh-session plugin load passed. A real pointer toggle saved
the Discord override; custom-class persistence and reset passed through the
helper. Native class fixtures rendered no added bar for Chrome/Discord and an
external bar for a frameless web app. Eighteen compositor-dispatched moves,
resize and minimize retained floating mode. A 1,200 × 820 pixel static region
afterwards exactly matched a temporary full-redraw reference: 984,000 pixels,
zero differences. Damage tracking was restored to its original value of 2.

The guarded native fixture is `tests/fixtures/titlebar-repaint.py`; it runs as
the desktop user only in the approved diskless QA VM. Snapshot comparisons
must exclude moving clocks/widgets and use VirtualBox framebuffer captures
so screencopy does not force a redraw before the comparison.

Physical dragging and manual keyboard entry were not validated by this fixture:
VirtualBox pointer dragging did not move the probe, and injected typing also
produced no input in the existing Settings search. The successful movement
checks used compositor dispatchers. Recheck ordinary typing, dragging and GPU
rendering on the installed desktop; these are not reported as passed.

The installer prints timestamped file-backup directories. Restore both scopes:

```sh
python ~/.local/state/forynarch/patches/r588-TIMESTAMP/restore.py restore ~/.local/state/forynarch/patches/r588-TIMESTAMP
sudo python /var/lib/forynarch/patches/r588-TIMESTAMP/restore.py restore /var/lib/forynarch/patches/r588-TIMESTAMP
```

Sign out and back in after restoring. Shipped files and the pre-patch titlebar
preferences/rules are restored; no applications or browser profiles are removed.
