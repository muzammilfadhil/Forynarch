# MacShell adaptations

Source: https://github.com/0-ss/MacShell
Revision: `18d9ceb682960aa96347e422e9b1578f1a4707cb`
Author: Rickky. License: MIT; the complete notice is in
`licenses/MacShell-MIT.txt` in the Forynarch source and documentation bundle.

`MacPlayerCard`, `MacPlayerArt`, `MacPlayerButton`, `MacPlayerGlyph` and
`MacMarqueeText` derive from the corresponding MacShell player components.
The host provides Forynarch's navy palette, optional album art, player selection,
lyrics and reduced-motion settings. The upstream wallpaper-crop glass loader is
removed: Forynarch uses compositor blur behind the actual translucent surface.

`shaders/liquid.frag` derives from `liquidglass.frag`: eight sampling taps instead
of twenty-four and a restrained blue tint requested for Forynarch. `LiquidGlass` consumes a single captured screen
frame while the optional control center is open; it does not keep a full-screen
capture running at idle. `MacControlCenter` is a Forynarch integration of the
upstream grouped-controls presentation, retaining the existing system backends.

The four-column packing algorithm, default tile order, dimensions, entry motion,
slider geometry, edit controls and `MacControlGlyph` Canvas drawings are adapted
from upstream `MacShell/MacBar.qml` at the revision above. `MacControlSurface`,
`MacControlButton`, `MacControlSlider`, and `MacControlPill` integrate that design
with Forynarch's bounded capture and reduced-motion settings. The optional single
frosted panel follows upstream's alternate presentation. `MacAudioDetails` is a
Forynarch addition, opened by right-clicking Sound. Bar, Control Center and music
appearance can be selected independently; choosing this Control Center does not
recolor the rest of the desktop.

Forynarch subsequently removes the recording tile and its backend, adds a subtle
blue material tint and audio resize transition, and wires the original player's
lyrics view to the shared media model. The player surface uses compositor blur
and Forynarch's `LiquidMusicSurface` rim/highlight, avoiding wallpaper crops and
continuous capture. Player scaling follows width to keep controls readable in
the taller lyrics view.
