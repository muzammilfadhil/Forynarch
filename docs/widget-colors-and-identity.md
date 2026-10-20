# Widget colors and product identity

The built-in analog clock, calendar, greeting and liquid music surface share
`config/quickshell/forynarch/WidgetPalette.js`. Change its surface, edge, chip
and text values to customize their colors. Existing widget imports and source
editing remain available; this does not lock third-party widgets to a palette.
Transparent cards use the compositor's real background blur. Disabling Glass
uses the same opaque navy base. No wallpaper copy or continuously animated
shader has been added. The clock repaints for minute changes or resizing;
hover lighting remains brief and respects reduced motion.

The standard GTK decoration order is **minimize, maximize, close**, from left to
right. It is set in the GTK 3/4 settings and GNOME window-manager schema defaults.
Window-preview controls use the same order. Applications that draw proprietary
title bars may need their own decoration setting.

**Settings → About** uses literal product identity in `SystemPage.qml`:

- Operating system: **Forynarch**
- Creator: **Muhammad Muzammil Fadhil**

These values are not loaded from user preferences, a hostname or mutable
`/etc/os-release` fields. Open-source forks can edit the source and rebuild;
hardcoded identity is a shipped UI choice, not a restriction on source editing.

Mudil Music remains an optional installer application. The widget reads its
MPRIS title, artist, artwork, playback state and supported playback controls.
Lyrics are opt-in: native MPRIS text is preferred, with LRCLIB as the metadata
lookup fallback. Availability depends on the track/provider; not every track
has lyrics. See [music and installation](wiki/screenshots-clipboard-and-media.md).
