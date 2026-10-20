# Capture, media and floating desktop work

Historical implementation notes. The completed feature verification supersedes
the progress statements below: [capture-media-panel-review.md](capture-media-panel-review.md).

This is an implementation record, not a release-completion claim.

Requested behavior:

1. Print Screen captures the full desktop; Super + Shift + S selects a region.
   The Screenshots utility and Settings choose file saving, clipboard copying
   and a screenshot folder. Clipboard-only operation creates no screenshot file.
2. Optional local clipboard history supports copy, individual deletion and
   clearing history plus the current clipboard. Super + Ctrl + V opens it;
   Super + V remains the existing float/tile shortcut.
3. An optional MacShell-style control center appears from the panel's right side,
   with navy Liquid Glass. Preserve the current panel style as the default.
4. The music widget can use the Forynarch or adapted MacShell card, select an
   MPRIS player, and toggle artwork, lyrics and the Forynarch Cava visualization.
   Lyrics are on-demand, with an explanation before sending track metadata.
5. Mudil Music is an unchecked setup/software option, never a core dependency.
   Its Linux build needs audio_service_mpris; the supplied package predates this
   integration and must be rebuilt. Mobile notification configuration stays intact.
6. Super + H minimizes the active window. Alt+Tab includes recoverable minimized
   windows only from the current workspace. Clicking its hotbar entry restores it.

Implemented so far: capture backend/UI and shortcuts, bounded SQLite history,
minimized-window Alt+Tab routing, optional music components and preferences,
MacShell player adaptations with MIT license/credits, and the Mudil source
dependency/configuration change. Native capture and clipboard checks passed.
The Arch QA suite ran 227 tests: OK, one skipped. Later media/panel changes still
require their own checks. Native minimized-window restoration, Mudil packaging,
Liquid Glass controls and the final ISO are not yet complete.

The R4.9 ISO built on 17 October cold-booted, but exposed an old Fastfetch config
in the precreated Live home. The factory migration now recognizes that exact
previous config; a corrected build is required before calling that ISO verified.

Reference: https://github.com/0-ss/MacShell at revision
`18d9ceb682960aa96347e422e9b1578f1a4707cb` (Rickky, MIT).
See `config/quickshell/forynarch/MACSHELL-SOURCES.md` and
`licenses/MacShell-MIT.txt`. No Apple logo or unrelated shell is installed.

Windows-wide tests currently encounter an existing widget-pack local-path failure
on drive-letter paths. Capture-specific Windows tests passed (9 tests). Required
desktop/runtime checks run in the disposable Arch VM, not on personal drives.
