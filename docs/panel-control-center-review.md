# Panel and Control Center review — 17 October 2026

## Scope and implementation

The bar, Control Center and music card have independent appearance preferences.
MacShell's four-column layout, Canvas glyphs, tile dimensions, sliders, edit
controls and staggered motion are adapted from the upstream revision recorded
in [the provenance file](../config/quickshell/forynarch/MACSHELL-SOURCES.md).
The Control Center keeps neutral glass rather than applying the desktop's blue
tint. Right-click Sound opens a matching device selector and application mixer.

Panel settings expose twenty bounded geometry and text preferences. Application
icons are centered, and preview headers provide minimize/restore, maximize/restore
and close actions. Right-side bar actions suppress tooltips while retaining
accessible names. Separate lazy panel instances prevent a saved bar style from
retaining the previous panel's exclusion margin after a shell restart.

Main files are `config/quickshell/forynarch/{shell,DesktopPanel,MacControlCenter,
MacAudioDetails,RunningApplications,WindowPreviews,PanelCustomization}.qml`, the
`MacControl*` components, `ControlCenterLayout.js`, `PanelMetrics.js`, and the
neutral `shaders/liquid.frag`. Existing system helpers provide hardware actions;
there is no new continuously running capture service.

## Verification

- Arch builder: `python -m unittest discover -s tests -p 'test_*.py'`:
  **241 tests, OK, 2 skipped**. Windows ran the same collection with 120 skips
  and one existing widget-path portability error; Arch is the authoritative run.
- Native Quickshell: `tests/run-panel-layout.sh`: **PASS**, including 100
  deterministic layout permutations, no tile overlap, ID validation, and all
  twenty preference boundaries. The fixture runs after engine initialization so
  its exit status is reliable.
- All three shader bundles compiled with the installed Qt shader compiler.
- VM: all four bar/Control Center combinations loaded. Forynarch's default
  reservation is 52 px; MacShell is 32 px after preference reload settles.
  Setting Forynarch bar height to 64 produced a 72 px reservation.
- Saved component selections and application spacing survived a shell restart.
- Actual mouse interaction: Sound right-click opened the neutral audio view;
  a silent `pw-cat` fixture appeared in the mixer, and its slider changed
  PipeWire channel volumes to 0.097336. The fixture was stopped afterward.
- Actual preview buttons: maximize set `fullscreen=1`; minimize moved the
  owned fixture to `special:forynarch-minimized`; restore returned it to its
  workspace; close removed it from the client list.
- Actual Edit Controls buttons removed Wi-Fi, repacked the remaining controls,
  and added Wi-Fi again. No QML component errors remained after fixes.

## Anti Slop delivery gate

- **Hard gate — PASS:** follows the user's requested upstream design; retained
  MIT notice and source revision; no unrelated decoration or new package default.
- **Purpose — PASS:** audio controls operate on actual PipeWire devices/streams;
  preferences persist; unavailable hardware/tools expose disabled states.
- **Liveliness — PASS:** bounded tile entry and button motion, real hover/pressed
  feedback, and reduced-motion handling; capture is released with the popup.
- **Craftsmanship/accessibility — PASS:** keyboard controls, focus indicators,
  accessible action names and bounded geometry. Contrast checker: secondary
  `#c5c5c9` on opaque fallback `#262629` **8.77:1**; primary `#f5f5f7`
  **13.86:1**. These figures describe fallback colors, not every captured pixel.

## Limits and hardware follow-up

Tests use Hyprland and Quickshell in VirtualBox at 1280×800. The VM has one
input and output and no Wi-Fi/Bluetooth adapters. Real multi-device routing,
radio reconnects, recording permissions, hardware brightness, and high-DPI
multi-monitor placement still need hardware verification. The VM uses SHM
capture fallback because it exposes no usable DMA-BUF render node; this is a
graphics capability warning, not a QML load failure. No installed-target memory
certification is inferred from Live VM readings.
