# Forynarch Glass desktop

The first visual prototype has been replaced by the
[Blue Hour desktop redesign](desktop-redesign.md). That report describes the
current UI, real input tests and current memory evidence. The original checks
below remain historical evidence; their older layout description is superseded.

Implemented as original QML and GLSL, tested in the existing Fornarch Live VM.
All interface text is English. This replaces the Waybar panel while retaining
Mako, Swaybg, NetworkManager, PipeWire, portals and the permission agent.
It does not install developer groups or run the end4-pC stack.

## Working features

- Rounded navy panel with workspace focus/highlight, launcher, files, live
  PipeWire volume/mute, network shortcut, settings and the existing session menu.
- Analog clock and current calendar cards. Time refreshes once per minute;
  workspace/audio information comes from service events.
- On-demand settings panel with three blue/teal accents, Glass/Light profiles,
  blur levels 2/4/6 and visible/hidden clock/calendar cards.
- Preferences saved atomically under XDG_STATE_HOME/forynarch/appearance.json,
  validated on load and retained after restarting the shell.
- Settings and widget groups use active loaders; closed settings and hidden
  widgets destroy their component trees. Light mode unloads shader surfaces.

The custom glass fragment shader uses nine bounded texture samples for blur,
static grain, a subtle edge highlight, a rounded alpha mask and a navy tint.
Its texture capture and SVG decode are bounded to half-resolution and not live.
The capture refreshes when the source image becomes ready or changes size.
There is no time uniform,
continuous shader animation or frame timer. Hyprland additionally blurs the
transparent Forynarch panel/widget/settings namespaces with two passes.

The clock/calendar and appearance controls are running UI, unlike the earlier
SVG concept. Weather, media cards, broad settings categories, monitor-local
workspace mapping and workspace default modes remain future work.

## Versions and renderer limitation

Executed on Hyprland 0.56.2-4, Quickshell 0.3.2-1, Qt 6.12.0 and qsb 6.12.0.
Shader compilation succeeds for GLSL 100 ES/120/150, HLSL 50 and MSL 12;
only the OpenGL runtime path was executed. Generated .qsb files are ignored
and excluded from source-transfer archives; the builder recompiles them.

VirtualBox's native graphics path failed with a wl_surface attach/EGL error.
The explicit --vm-renderer option uses Mesa software OpenGL so real GLSL
effects can still be tested. Physical hardware retains its native renderer;
GPU efficiency, frame pacing and battery behavior are not verified.
Do not report this software-rendered VM as a successful physical-GPU benchmark.

## Install and run a disposable Live preview

The reviewed Live transaction added quickshell, cpptrace, elfutils, libdwarf,
qt6-svg and qt6-wayland, 18.67 MiB installed in this snapshot. qt6-shadertools
was separately used for compilation in the test/build environment. That compiler
is not added to the independent installed-target runtime manifest.

With reviewed prerequisites already available:

```bash
bash scripts/install-glass-preview.sh --approve-live-preview
# Run as the ordinary desktop user:
forynarch-glass-start --vm-renderer
```

The preview installer verifies the reviewed package versions, backs up existing
configuration in Live RAM, compiles the shader and installs only preview files.
It does not install packages or restart the compositor. Confirm the shell starts
before stopping the previous Waybar panel. Live preview changes disappear when
the original ISO is restarted.

## Build integration

The canonical pipeline supports an explicit glass profile:

```bash
sudo bash scripts/forynarch.sh build --desktop-shell glass \
  --approve-host-packages --approve-target-packages --approve-image-config \
  --allow-core-dependency python
```

This requires the previously reviewed Waybar/gpsd/Python runtime exception;
the Python developer group remains unselected. The fallback Waybar stack still
belongs to the independent core candidate, so its dependency is not removed.

The approved builder update installs qsb through qt6-shadertools on the builder.
The runtime core adds quickshell only for this explicitly selected profile.
Shader bundles, QML, the launch helper and a desktop selection marker are copied
to the target and Live profile. VirtualBox startup selects the tested VM renderer;
real hardware keeps native OpenGL. Classic remains the default build profile
until longer/hardware QA justifies changing it.

Windows provisioning also exposes -DesktopShell glass and
-ApproveBuilderPackageUpdate. This iteration did not rebuild/boot a glass ISO:
the existing builder's SSH stopped answering banner exchange; orderly power
requests and pause/resume did not restore access during this task. The existing
desktop-preview ISO is unchanged and does not contain this new shell.

## Executed verification and remaining gates

- GLSL compiles to a qsb bundle and renders in the software-OpenGL VM.
- UI parses/loads; Hyprland configerrors is empty.
- IPC confirms settingsLoaded true while open and false after close.
- Escape closes the focused settings panel; focus handling was fixed and
  verified with VM keyboard input. Qt logs a nonfatal Wayland text-input focus
  warning during some panel transitions.
- Glass/Light, widget visibility, accent and frost values change and persist
  across a complete shell restart. Invalid preferences are ignored.
- Clock/calendar, workspace highlight and PipeWire volume render. Actual audio
  playback and clicks on every menu action are not all tested.
- 46 unit tests pass on Windows (0.876s) and Arch Live (0.174s).
- All Bash scripts pass syntax checks and official ShellCheck 0.11.0.
  The portable release archive SHA256 was checked against the GitHub asset digest:
  8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198.
  Installing Arch's dynamically linked ShellCheck exceeded the Live overlay's
  free space and committed no packages; the verified portable tool avoided its
  large Haskell dependency transaction.

Short development-session memory checks, 6 samples each at nominal 5-second
intervals, use MemTotal minus MemAvailable for the entire Linux guest:

| Profile/state | Peak used bytes | Peak GB decimal | Swap |
|---|---:|---:|---:|
| Light, clock/calendar shown | 1,238,507,520 | 1.239 | 0 |
| Glass, clock/calendar shown | 1,214,078,976 | 1.214 | 0 |
| Glass, settings open | 1,434,959,872 | 1.435 | 0 |

Each collector exits 0 below the 3,000,000,000-byte limit. Small cross-profile
differences reflect caches and timing; they do not prove Glass uses less memory.
An earlier development run including configuration reload reached 1.501 GB.
After the final bounded SVG decode change and a clean shell restart, another
6-sample check with settings open peaked at 1,376,047,104 bytes (1.376 GB),
with no swap and a successful collector exit. The final configuration loaded
without shader errors; the nonfatal text-input warning remains.
The following 6-sample check after closing settings peaked at 1,353,535,488
bytes (1.354 GB), with no swap. Its raw output is retained under ignored
out/virtualbox/glass-optimized-idle-memory.txt. Windows PowerShell reported
NativeCommandError for the collector's informational stderr line, so that
wrapper's exit is not used as evidence of the Linux collector exit.
These are short Live/development measurements, with preview/compiler/debug
processes present, not controlled installed-target cold-boot acceptance tests.

Remaining: glass-profile ISO build/boot, actual installed target, three cold boots
with 10-minute idle samples, repeated open/close leak tests over 60 minutes,
1/2 monitors, physical GPU rendering, suspend/audio and battery measurements.
Next smallest action is restoring builder access, then building the explicit
glass profile and running a fresh Live boot before installer/hardware QA.

References checked before coding:
[Quickshell 0.3 PanelWindow](https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/),
[FileView](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/),
[IPC](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/),
[PipeWire](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Pipewire/Pipewire/),
[Qt ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html),
[qsb](https://doc.qt.io/qt-6/qtshadertools-qsb.html),
[Hyprland layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/).
