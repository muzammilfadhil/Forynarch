# Core runtime dependency evidence

## Kath video runtime update (15 October 2026)

The owner selected the Kath MP4 as the SDDM background. Qt Multimedia 6.12.0
requires a backend; the explicit runtime choice is qt6-multimedia-ffmpeg.
Official Arch FFmpeg 9.0.2-2 also depends on VapourSynth, which depends on Python.
This adds a second runtime chain, `qt6-multimedia-ffmpeg -> ffmpeg ->
vapoursynth -> python`, alongside the existing Waybar/gpsd chain. The developer
Python/pip group remains unselected. No compiler, pip or developer group is
selected by the video feature.

The build still requires `--allow-core-dependency python` and records package
metadata in the bundle. Its guard accepts only gpsd, or gpsd plus vapoursynth,
as Python consumers, and checks the video chain when present. Any other consumer
requires review. A fresh installed-target package audit remains pending;
portable library extraction for preview is not an installed package audit.
Sources: [Arch Qt Multimedia](https://archlinux.org/packages/extra/x86_64/qt6-multimedia/),
[FFmpeg backend](https://archlinux.org/packages/extra/x86_64/qt6-multimedia-ffmpeg/),
[FFmpeg](https://archlinux.org/packages/extra/x86_64/ffmpeg/) and
[VapourSynth](https://archlinux.org/packages/extra/x86_64/vapoursynth/).

## Earlier Waybar runtime review

Observed on the approved Arch builder, 14 October 2026. This distinguishes developer group selection from package dependencies; it does not claim that Python is absent from every minimal Arch desktop.

The selected official package **Waybar 0.15.0-3 requires gpsd 3.27.5-1**, which **requires Python 3.14.8-1**. The first core build correctly stopped on this dependency instead of silently treating it as approved. Installed package metadata was inspected before continuing. Python is a dependency, not an explicit core request or a selected developer group.

This is the AGENTS.md exception for documented mandatory transitive runtime dependencies of chosen OS components. The approved automation scope includes building the required desktop; it does not automatically select Python/pip development groups. Continue only with the narrow --allow-core-dependency python gate, which verifies this exact Waybar/gpsd dependency relationship and saves metadata evidence. A changed chain fails review again.

The generated bundle includes core-runtime-exceptions.txt and python-dependency-evidence.txt, both covered by SHA256SUMS. The installer displays the exception before disk consent. Python/pip groups remain unchecked; no pip or SDK is installed by this exception. The runtime's presence must be reflected in zero-selection test expectations.

Using the upstream Arch Waybar package avoids maintaining a custom unsigned build. Achieving absolute Python absence would require separately evaluating a Waybar build without its GPS module or a different bar; neither is silently substituted here. GPS daemon enablement and idle power must be checked independently—package presence alone does not mean a service runs.

The audio candidates now explicitly use pipewire-jack to choose the PipeWire compatibility provider rather than allowing an arbitrary JACK provider. This is OS audio integration, not an optional developer toolkit.
