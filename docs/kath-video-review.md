# Kath video background

Owner update, 15 October 2026: use the supplied Kath MP4 as the default SDDM
background. This supersedes the static-default decision in the
[earlier review](connectivity-and-kath-review.md).

## Changes and dependencies

The supplied video is byte-identical to the retained upstream Kath MP4:
SHA-256 `1ddffbd4d38bc13e9b9f31446fa4cabf102bca1a48291dd542745539ba3fe8c3`,
1,071,339 bytes. It is H.264, 1920 x 1080, 15 fps, approximately 13.67 seconds.
No re-encoding or frame-rate increase was applied. Theme configuration now
selects the MP4, retaining the PNG as a loading/error fallback. Its stacking
keeps the login form and controls visible when playback fails. The local blur
fade follows the video; the four confirmed power actions remain unchanged.

Affected source: `config/sddm/themes/forynarch-kath/`,
`packages/target-core.proposed.txt`, the dependency guard in `scripts/forynarch.sh`,
and the native `tests/run-login-video.sh` fixture.

Runtime packages are Qt Multimedia 6.12.0-1 and its FFmpeg backend, with official
Arch FFmpeg 9.0.2-2. [Qt MediaPlayer](https://doc.qt.io/qt-6/qml-qtmultimedia-mediaplayer.html)
provides infinite looping. The FFmpeg dependency closure introduces a second
mandatory Python runtime chain through VapourSynth; see the
[dependency record](runtime-dependencies.md). The existing explicit build flag
`--allow-core-dependency python` remains required, dependency metadata is recorded,
and unknown consumers fail review. Developer groups remain unchecked. This
change performs no package installation; fresh target package audit is pending.

## Verification

- PASS: supplied-file hash matches the shipped MP4.
- PASS: native production video component advances, wraps into another loop and
  emits failure for a missing source. The deliberately missing-source fixture
  produces an expected FFmpeg warning, then exits 0 on all assertions.
- PASS: actual SDDM 0.21.0-7 test-mode preview plays the video with the navy form,
  moving local blur and all four power controls visible at 1280 x 800.
- PASS: Arch Python suite, **104 tests**, **2.411 s**, no skips; Bash and
  ShellCheck exit 0. New video runner is included in shell checks.
- PASS: six isolated runtime-policy fixtures exercise the actual build guard:
  the existing and video chains pass; unknown consumers, a broken video chain,
  missing approval and explicit core Python selection fail. These use mocked
  package metadata and do not replace a fresh target transaction audit.
- PASS: runtime packages used for preview were signature-verified and extracted
  to temporary folders. No package hooks, services, authentication or power
  actions were executed. The preview copy disables sign-in and power.

Six samples five seconds apart, with the existing Live desktop and portable
greeter running together, peaked at **1,573,588,992 bytes** used
(`MemTotal - MemAvailable`), swap **0**. Greeter RSS was **355,061,760 bytes**.
These values are Live snapshots, not installed-core idle acceptance. Temporary
runtime extraction and desktop activity also differ from the earlier static run;
do not attribute the entire system-memory difference to video alone.

The VM explicitly uses software rendering and reports no hardware decoder.
Greeter CPU was **111.56% of one core over 25 seconds**. Video plus dynamic blur
therefore has a substantial CPU cost in this environment. Physical GPU decode,
power draw and real SDDM login/exit lifecycle remain untested. The earlier
static CPU result must not be used to describe the video version as low-power.
If hardware testing shows an unacceptable cost, the existing PNG remains a
configuration option; the owner-selected default is still video.

Antislop delivery gate: PASS for owner-selected artwork, retained navy palette,
readable form, working loop, fallback signal, and visual bounds. Hardware power
and installed RAM gates remain PENDING. No new ISO or target installation was
made. Generated screenshot: `out/virtualbox/kath-video-preview.png`.
