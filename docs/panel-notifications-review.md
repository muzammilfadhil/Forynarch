# Panel, tray and notifications review — R4.8

## Intent and files

Improve first-hover previews, align running-app indicators, hide Firefox's
classic menu bar, add a compact StatusNotifier tray grid, and expose native
notification history, DND and custom focus. Files include RunningApplications,
WindowPreviews, DesktopPanel, BackgroundApps, NotificationCenter,
NotificationsPage/Model, shell/settings catalogs, the notification helper, Mako
configuration, browser policy staging, shortcuts and session integration.

## Dependencies and behavior

Verified runtime: Hyprland 0.56.2-4, Quickshell 0.3.2-1, Mako 1.11.0-1,
Firefox 157.0.1-1. No package group or new background daemon is introduced.
Native tray menus require Quickshell's QApplication pragma, using the existing
Qt runtime and GTK3 platform theme. Its native menu was tested through keyboard
Tab/Menu and follows the dark theme. All shipped UI and help remains English.

Preview hover delay is 110 ms. Up to three application groups are prepared
ahead of hover, with stable delegate identities and at most three visible-page
snapshots per group. Metadata/focus changes do not rebuild unchanged thumbnails.
Hidden captures do not run a refresh timer; software rendering uses snapshots.
The cache is released on app removal or eviction. Capture buffers may be source
resolution; no claim of thumbnail-sized GPU memory is made.

The left island sizes from its actual row and equal outer padding. The center
clock shortens on narrow monitors. The tray is an icon-only grid, scrollable
after six rows, with app tooltips, activation and native app menus.

Mako supplies banners, actions and session history. Settings generates a small
mode fragment while retaining user rules. It supports banner enablement and
duration, strict DND, and custom app allowlists with optional critical alerts.
The center reads only while loaded; a notification callback sets the unread dot.
Unchanged poll results preserve the existing notification rows and keyboard focus.
Critical timeouts remain indefinite when alerts are permitted.

Maximize shortcuts and shell buttons use the same helper and explicitly select
Hyprland's monitor fullscreen handler (`layout_aware=false`) for maximize.
True fullscreen remains separate. Native floating and tiled fixture windows
stayed inside the reserved monitor work area. The reported downward overflow
was not reproduced on the tested 1280×800 single-monitor setup; fractional
scaling, rotated/multiple displays and native CSD requests need separate checks.

## Verification

Arch suite: 210 tests, OK, two native-Zsh checks skipped. Generated shortcuts,
Bash syntax and ShellCheck pass.

Notification policy changes remain successful when the panel is busy and its
best-effort badge callback times out. A regression test covers that case;
native DND, allowlist and action tests passed again afterwards. The maximize
fixture also verifies restoration of the original floating position and size.

Native fixtures verify:


- DND suppresses a critical banner without discarding the message.
- Custom focus blocks unlisted apps/critical alerts and displays allowed apps.
- A real notify-send action reaches its sender; dismissed messages enter history.
- A dedicated floating and tiled Alacritty test stays within monitor bounds.

Initial software-renderer preview trials still took seconds. After bounded
preparation and stable models, the first prepared Firefox hover logged
`PREVIEW_CACHE_HIT_MS 125` and `PREVIEW_OPEN_MS 125`. This is one VM observation,
not a hardware-wide latency guarantee; an unavailable/evicted source can still
need a fresh capture. Trace output is opt-in through
`FORYNARCH_PREVIEW_TRACE=1` and is absent in normal sessions.

Normal-text contrast checks passed at 10.15:1 (`#b5c9e3` on `#111c2b`) and
12.69:1 (`#deebfc` on `#172638`). Readable text, focused controls, outside-click
closure and Escape are provided. Native input/menu and resize checks are
recorded below as they complete. Installed-core memory acceptance remains
separate from Live VM measurements.

## Built artifact and cold-boot limits

Windows artifact: `out/iso/forynarch-2026.10.16-blue-hour-r4.8.iso`,
3,966,468,096 bytes. SHA-256:
`7b5742fb560435cd65a4fa5be906e9a0b9bc3499db873aa6a07696370ee62a98`.
Builder and Windows hashes match. Staged target/Live source comparisons,
executable permissions, Firefox policy, optional-package gates and all bundle
checksums passed. The bundled review is the pre-build source snapshot; this
repository review records subsequent artifact checks.

The first candidate reached SDDM but did not enter a usable desktop. Both 3D
configurations authenticated the blank-password Live user and returned to the
greeter after Hyprland failed during backend initialization. Investigation found
that staging had pre-created a root-owned `/home/liveuser`; `useradd --create-home`
therefore skipped copying `/etc/skel`. Live preparation now seeds missing files,
creates the SDDM session-log directory and assigns ownership to Liveuser under
the existing Live-only and fixed-home guards. An isolated native check verified
writable ownership, complete desktop configuration and safe repeated execution
without overwriting existing files. The repaired Live session passed all native
notification/maximize tests again. The first candidate is retained only as
`blue-hour-r4.8-pre-home-fix.iso`; its rejected SHA-256 starts `12687953`.
The replacement artifact above includes the Live-home fix. Installed-core
memory has not been remeasured for this revision.

Six samples after five idle minutes in the repaired Live VM used
`MemTotal - MemAvailable`: peak 1,245,405,184 bytes, swap 0. This was the
candidate Live session with the final home-preparation repair applied, not an
installed-target benchmark. No user applications remained open; default
desktop widgets remained enabled. Quickshell RSS was about 747 MB with the VM
software renderer. That RSS includes shared allocations and must not be added
to the system used-memory measurement.

The replacement ISO subsequently passed an unmodified cold boot with VirtualBox
3D enabled. Liveuser entered Hyprland automatically. Read-only native acceptance
confirmed home ownership, writability and required desktop configuration; the
session had one compositor, no Hyprland config errors, normal notification
profile and six-second default timeout, the Firefox policy and maximize helper.
No runtime source patch was applied. All native notification and floating/tiled
maximize/restore fixtures passed again against this exact ISO. The fresh cold
boot does not turn the earlier Live memory observation into an installed-core
measurement. Fractional and multiple-monitor maximize remain untested.

## Reference links

Firefox's `about:policies` page showed `DisplayMenuBar = "never"` as active;
the classic menu bar was absent. The isolated QA tray displayed the real
NetworkManager item and its functional native context menu using Tab/Menu.
The menu inherited the dark GTK palette without adding a settings daemon.

- [Quickshell tray API](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.SystemTray/SystemTrayItem/)
- [Quickshell application pragmas](https://quickshell.org/docs/v0.3.0/guide/advanced/)
- [Mako control API](https://man.archlinux.org/man/makoctl.1.en)
- [Mako modes and configuration](https://man.archlinux.org/man/mako.5)
- [Firefox policy reference](https://mozilla.github.io/enterprise-admin-reference/reference/policies/)
- [Hyprland fullscreen handlers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/)
