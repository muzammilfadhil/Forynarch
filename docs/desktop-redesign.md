# Blue Hour desktop redesign

The [search/widget/motion iteration](search-widgets-motion.md) now supersedes
the original Fuzzel launcher and single widget-visibility control described here.

## Intent and affected source

Replace the first Glass prototype's repeated text pills, sparse settings form
and unrelated desktop cards with a coherent everyday desktop. The reference is
the complete [end4-pC screenshot gallery](https://github.com/pctrade/end4-pC/tree/main/screenshots),
especially [screenshot 3](https://github.com/pctrade/end4-pC/blob/main/screenshots/3.png).
My visual reading of the references is that grouping, hierarchy, a compact
navigation rail and readable surfaces matter more than adding more effects.

The implementation is original QML, Canvas icons, GLSL and SVG, not copied
upstream widgets, photos, characters or branding. Linux interface text is English.

Affected source: config/quickshell/forynarch, assets/wallpapers/navy.svg,
config/gtk-3.0/gtk.css, Foot/Fuzzel/Mako colors, scripts/forynarch.sh and the
disposable Live preview installer. Installer selections and workspace/window
behavior contracts are unchanged.

## Changes that are running

- Three panel islands: launcher/workspace context, workspace navigation/date,
  sound/network/settings/session. The date opens the calendar settings page.
- A blue scalloped analog clock, compact current-week calendar, real account
  greeting and MPRIS music card. With no player, the music card shows an honest
  empty state and disables transport controls.
- Five real settings pages: Appearance, Panel, Desktop, Shortcuts and About.
  Sidebar navigation switches content inside the window instead of opening
  unrelated programs. Each page is loaded on demand into a scrolling viewport.
- A wallpaper preview, three named accents with checkmarks, a glass switch and
  named blur strengths. The original Blue Hour SVG replaces the earlier logo
  wallpaper; it has no distracting text behind open windows.
- Working top/bottom panel placement, Continuous/Islands layout, widget
  visibility and 12/24-hour clock. Values join existing appearance preferences
  in the atomic JSON state file.
- A quick-controls popover with a real PipeWire volume slider, mute, network,
  appearance, lock and the existing session menu. Only normal settings actions
  were exercised; power, lock and installer operations were not triggered.
- Escape and outside-click dismissal. Settings dims/blurs the desktop behind
  it; the content stays readable. Buttons support keyboard focus, Return/Space,
  descriptive accessible names and themed tooltips. Toggles and the slider use
  native Qt Quick control input.
- GTK 3 palette overrides retain Adwaita's sizing/behavior. Launcher, terminal
  and notifications share the new palette. Existing app processes need their
  next normal launch to pick up file-based GTK/terminal styles.

The shader retains nine bounded texture samples, half-resolution static
captures, static grain and a subtle highlight. A radius uniform keeps different
surfaces consistent. There are no continuous shader animations. The clock's
only timer runs once per minute; audio, workspaces and media use service events.
Closed popovers/settings and hidden widget trees are unloaded.

## Assumptions and versions

Executed on Hyprland 0.56.2-4, Quickshell 0.3.2-1, Qt/qsb 6.12.0, GTK 3.24.52
and VirtualBox 7.2.20. The glass build profile explicitly adds adwaita-fonts
(tested Live version 51.0-2) for the shell's typography. This is a font runtime,
not a developer group; all developer group selections remain opt-in.

The existing VirtualBox native renderer failure still applies. This preview
uses software OpenGL; physical GPU rendering, frame pacing and battery cost
have not been validated. The new shader bundle compiled successfully in Arch.

## Executed checks

- Windows source checks: 46 tests, 0.831s, OK; all Bash syntax checks pass.
- Arch Live: 46 tests, 0.182s, OK; portable official ShellCheck 0.11.0 exits 0.
- Shell configuration loads with no shader/QML errors; Hyprland configerrors
  is empty. Nonfatal Qt Wayland text-input warnings remain on focus transitions.
- Real VM mouse input switches sidebar pages, panel position/layout and clock
  format; status and persisted JSON confirm the values. A full shell restart
  retained Bottom + Continuous + 12-hour preferences; defaults were restored
  to Top + Islands + 24-hour afterwards.
- Escape closes settings/controls; a click outside closes controls and destroys
  their loaded tree. Settings uses the same outside-click dismissal structure.
- Tab moves focus from Panel to Desktop; Return opens that page, confirmed
  through actual VM keyboard input and shell status.
- Real mouse input mutes PipeWire. A slider hit-area defect was found and fixed
  by giving the customized control a 32px height. Clicking the track changed
  wpctl volume from 0.40 to 0.71; Right Arrow changed it to 0.72. It was restored
  to unmuted 0.40. No audio playback was tested.
- The panel launcher button opens Fuzzel with the new colors. Search selection
  and app/power/network actions were not exhaustively exercised.
- GTK 3 CSS is supplied and copied, but fresh Thunar rendering is not confirmed.
  Its preferences wrapper reused an existing process. A private test bus
  encountered a GVFS mountpoint permission error and was stopped; the user's
  existing Thunar windows were preserved. Validate GTK colors on the next
  normal cold boot rather than treating those attempts as a successful UI test.
- All five settings pages were reached during inspection. The calendar is
  Monday-first and uses the English locale. MPRIS has no active player in this
  VM, so only the empty state was executed.
- Runtime screenshots are saved under ignored out/virtualbox/glass-redesign-*.png.
  They are VM captures, not mockups or generated concept images.

Memory checks use MemTotal minus MemAvailable for the entire running Linux
guest, including the user's existing terminal and file-manager processes.
Six samples at nominal five-second intervals, limit 3,000,000,000 bytes:

| State | Peak bytes | GB decimal | Swap | Collector exit |
|---|---:|---:|---:|---:|
| Glass desktop, widgets shown | 1,360,089,088 | 1.360 | 0 | 0 |
| Glass settings open | 1,521,618,944 | 1.522 | 0 | 0 |

Raw output: out/virtualbox/glass-redesign-idle-memory.txt and
out/virtualbox/glass-redesign-settings-memory.txt. These are short Live
development measurements, not three cold boots of an installed target.

## Not tested and next action

A 1024x768 VirtualBox video-mode hint did not change the guest's 1280x800
output, so it is not evidence of smaller-screen testing. The hint was restored
to 1280x800. Verify 1024x768 and fractional scaling on a guest/hardware that
actually changes output mode; inspect all pages and keyboard traversal for
clipping and focus order.

No new ISO was built: the builder SSH banner failure from the previous task
remains unresolved. The existing ISO does not contain this redesign. Restore
builder access and build the explicit glass profile, then test a fresh Live boot
and the independent installed target. Further gates: repeated open/close leak
test, three 10-minute cold-boot idle runs, 1/2 monitors, active MPRIS playback,
network/audio/suspend, physical GPU and battery tests. The full Forynarch vision
still applies; this UI iteration does not complete those OS features.

Official APIs checked before implementation:
[Qt Quick Slider](https://doc.qt.io/qt-6/qml-qtquick-controls-slider.html),
[Quickshell MPRIS](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Mpris/MprisPlayer/),
[GTK CSS](https://docs.gtk.org/gtk3/css-overview.html), and
[VirtualBox SDK](https://download.virtualbox.org/virtualbox/7.2.2/SDKRef.pdf).
