# end4-pC reference and the 3 GB idle requirement

Implementation update: the [Glass shell](glass-shell.md) now runs in the test
VM with real shader surfaces and appearance controls. This document preserves
the preceding source audit and baseline; glass-profile ISO/hardware QA is pending.

User-selected reference: [screenshot 3](https://github.com/pctrade/end4-pC/blob/main/screenshots/3.png).
Analysis snapshot: upstream commit `a837ef77d5f4a3643996e4dbdffe7ec9f480724a`,
retrieved 2026-10-14. Upstream code was inspected, not installed or executed.
Downloaded reference files and measurement output remain in ignored out/.

## What the selected screenshot contributes

The reference combines a thin rounded top panel, desktop clock/weather/calendar
cards and a large settings overlay with a left navigation rail. Wide spacing,
grouped controls, rounded chips and a restrained accent palette matter more
to this look than the number of background services. Forynarch's direction is
navy surfaces, sky-blue selected states, cream text and sparse peach highlights.

An original blue study is in assets/concepts/blue-control-center.svg. It is a
static mockup: weather values, widgets, settings controls and buttons are not
implemented functionality. No upstream code, wallpaper or avatar was copied
into this asset. The current working ISO remains the previously tested desktop.

## Findings from source

1. The README identifies this as a Quickshell shell that expects the underlying
   illogical-impulse setup. Installing the whole setup is a larger scope than
   adopting its visual layout. Its setup command uses Git for source checkout;
   shell.qml also references a conditional Python autostart helper. Forynarch
   must independently audit its runtime package policy before any adoption.
2. shell.qml initializes multiple services at startup, including wallpaper,
   update, football and lyric functionality. The panel family instantiates many
   scopes. PanelLoader's default active condition is configuration readiness;
   it does not automatically unload every scope when a particular panel is hidden.
3. There are genuine conditional loaders. For example, the dashboard settings
   window is loaded only while dashboard settings are open. Wallpaper blur and
   other effects also have conditions. It would be incorrect to claim that all
   features render continuously or that the project has no lazy loading.
4. Classic Settings.qml uses a visibility flag on its settings window and
   contains UI children inside it. This suggests resident hidden UI deserves
   profiling, but cannot determine its actual memory use from source alone.
5. Background.qml supports blur, collage and shader transitions; LiveWallpaper.qml
   controls mpvpaper. VisualizerEngine documents a Cava-driven shader path. These
   are candidate costs when enabled, especially for graphics/power. Their existence
   does not establish defaults, leaks, or gigabytes of resident RAM.
6. ResourceUsage.qml calculates used memory from MemTotal minus MemAvailable.
   Its timer changes to the configured interval (default 3000ms) after updating
   and is gated by consumers. Its initial interval of 1 is not proof of a
   continuously running 1ms poll. Do not dismiss its RAM reading as merely free
   page cache or misrepresent this polling implementation.

There is no end4-pC memory benchmark executed in this audit. The user's high-RAM
observation remains unquantified here; exact causes require their enabled preset,
the base installation, process memory and before/after measurements.

## Forynarch acceptance target

The user requires **idle used memory strictly below 3,000,000,000 bytes**
(3 GB decimal, approximately 2.79 GiB). Engineering preference: leave headroom,
aiming for 1–1.5 GB on the reference system. That lower range is a design target,
not a result or guarantee for the proposed richer shell.

Measure within the Forynarch Linux guest/installed OS using
`MemTotal - MemAvailable`; record swap use separately. Windows' VM allocation,
ISO disk size, and the sum of RSS values are different measurements. Process
PSS is useful for attribution because shared libraries can be counted repeatedly
in an RSS sum. Integrated graphics allocations vary by hardware and must be
covered by actual supported-hardware tests.

Release protocol:

- Independent minimal installed target, no optional developer/application groups.
- Cold boot, login, wait 5 minutes, no foreground apps, no build/download/update
  job. Required networking, audio, permissions and desktop services stay running.
- Sample every 5 seconds for approximately 10 minutes, three cold boots.
- All samples below the hard limit; no sustained swapping to hide memory use.
- Repeat after opening and closing settings/launcher and using widget controls;
  inspect growth over a 60-minute session and compare process PSS.
- Repeat with 1/2 monitors and documented resolution/scaling on real graphics
  hardware. Record the Live ISO separately because its RAM filesystem, services
  and page cache differ from an installed rootfs.

Read-only collector (no root, package install or cache clearing required):

```bash
bash scripts/measure-idle.sh 120 5 3000000000 > idle-samples.jsonl
```

It exits 1 if any sample reaches/exceeds the limit. It cannot itself prove the
session was idle; the test operator records that context. The measurement
output should be kept under ignored out/ when used inside this repository.

## Executed baseline snapshot

On 2026-10-14, the existing disposable Fornarch Live VM (8 GiB configured RAM,
Hyprland 0.56.2-4 on Linux 7.2.9) was sampled 12 times at a nominal 5-second
interval. Used bytes ranged from **855,883,776 to 856,780,800** (peak 0.857 GB,
approximately 817 MiB); mean 856,343,211 bytes. Swap used was 0 throughout.
The collector exited 0 against the 3,000,000,000-byte limit.

This was an already-running development Live session with temporary preview
changes and additional debug/session processes. It was not a controlled cold-boot
installed-target benchmark, did not run end4-pC, and did not include the richer
blue mockup as a running shell. It supports feasibility without proving future
widget memory costs. Raw JSON samples are in ignored
out/references/end4-pC/forynarch-live-memory.jsonl.

Collector checks on the Arch builder passed Bash syntax and shellcheck. A single
sample returned exit 0 below a 3 GB threshold, exit 1 above a deliberately tiny
1-byte threshold, and exit 2 for invalid input. The 45 existing Windows unit tests
passed (1.180s). The blue SVG was rendered in an isolated headless browser profile
as a visual check, not as a functional desktop test. No upstream stack/package
was installed, and no disk/account/EFI change was made for this analysis.

## Blue implementation approach (proposal)

Start with a minimal Quickshell/QML prototype in a disposable VM and compare
it against the existing Waybar/Mako/Swaybg desktop. Official Arch currently
offers quickshell 0.3.2-1 in Extra; verify the installed release and dependency
transaction when implementing. QML's JavaScript does not require Node/npm.
No developer package group is enabled by this proposal.

Prototype only the panel, clock/calendar cards, a settings sidebar and selected
appearance controls. Weather is opt-in with infrequent cached updates; media
uses player signals. Settings pages instantiate while open and unload afterward.
Static wallpaper, limited image caches and opaque surfaces come first. Blur and
animation are bounded options; video wallpapers, audio visualizers, AI helpers,
online galleries and unrelated update/football integrations are not prerequisites
for the selected appearance.

Quickshell is not inherently established as heavier or lighter by this analysis.
The prototype must pass the memory gate before becoming the default. If it
replaces panel/wallpaper/notification duties, stop the equivalent existing
components so both full stacks do not remain resident. Preserve a tested
lightweight desktop fallback. Keep runtime dependencies separate from optional
Git, Python developer selections, Node/npm and toolchains.

Next smallest implementation: benchmark a blue panel plus on-demand settings
prototype, compare clean-session memory with this recorded baseline, and retain
only the widgets that fit the measured budget.

## Primary sources

- [Upstream README](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/README.md)
- [Shell startup](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/shell.qml)
- [PanelLoader](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/panelFamilies/PanelLoader.qml)
- [Classic settings](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/modules/ii/settings/Settings.qml)
- [Dashboard loader](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/modules/ii/settings/Dashboard.qml)
- [Resource accounting](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/services/ResourceUsage.qml)
- [Background](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/modules/ii/background/Background.qml)
- [Live wallpaper](https://github.com/pctrade/end4-pC/blob/a837ef77d5f4a3643996e4dbdffe7ec9f480724a/services/LiveWallpaper.qml)
- [Arch Quickshell package](https://archlinux.org/packages/extra/x86_64/quickshell/)
- [Kernel memory accounting](https://docs.kernel.org/filesystems/proc.html)
