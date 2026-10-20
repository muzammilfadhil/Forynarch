# Installer reference revision, 15 October 2026

The owner supplied a nine-step installer screenshot and requested its styling,
the existing Forynarch colors, lightweight shaders and motion. This supersedes
the earlier flat Welcome composition in [the first UI review](installer-ui-review.md).
Antislop 3.2.20 DURING remains the explicitly selected session mode.

## Changes and dependencies

The native installer keeps its navy and pale blue identity, adds nine stage
segments, and uses a rounded Welcome hero with blue light folds, outlined feature
illustrations and an explicit preview notice. At wide desktop sizes the two
feature rows share a grid; below 720 px of content width they stack. The navigation
rail remains useful on desktop. Footer actions remain outside scrolling.

Affected implementation: `WelcomePanel.qml`, `shell.qml`, `shaders/welcome.frag`
and the scoped `DESIGN.md` under `config/quickshell/forynarch-installer/`.
`scripts/build-installer-shader.sh` compiles the asset on Linux; the ISO pipeline,
disposable Live preview installer and native QML test runner all include it.

Runtime checked: Quickshell 0.3.2-1, Qt 6.12.0, Hyprland 0.56.2. Shader compiler:
qsb 6.12.0 from qt6-shadertools 6.12.0-1. Qt requires precompiled shader packages
and a std140 uniform block; see the [official ShaderEffect documentation](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html).
The build helper packages GLSL, HLSL, MSL and SPIR-V variants. Only the OpenGL
VirtualBox path was rendered here; other graphics backends remain untested.

The compiler is now a host requirement for both desktop build variants because
both provide the Live installer. Compilation fails early, before target package
installation. Only the compiled installer asset goes into the Live configuration;
the independent installed target gains neither this installer nor the compiler.
Generated QSB assets remain ignored. Existing developer-package choices stay off.

## Effect and motion budget

- One bounded hero ShaderEffect, one analytic fragment pass and no sampled textures
  or full-window blur capture. The existing desktop glass remains separate.
- A finite 680 ms light arrival; a 140 ms page fade and an 8 px, 200 ms page arrival.
  No frame timer, looping effect, extra process or background service.
- Reduce motion prevents the hero arrival and immediately settles an active one;
  page animations then have zero duration. An unsupported shader falls back to
  the solid navy surface. The native test requires the shader to actually compile.
- Shader RGB is bounded by (0.16, 0.28, 0.42), preserving text contrast throughout
  motion. The Live preview badge has its own opaque dark background.

## Verification

- Arch Live: **101 tests passed, no skips, 1.810 s**. Windows: **101 discovered,
  53 passed and 48 Linux-only skips**, exit 0.
- Native production-QML regression passes shader compilation on the active renderer,
  finite motion settlement and reduced-motion suppression, then all nine pages,
  account validation, secret isolation, offline reset, software/driver opt-ins,
  inventory error/retry, empty storage, equal-width account fields and modal focus.
- Bash syntax passed for all shell scripts and both native QML runners. Builder
  ShellCheck passed without findings. No package installation was needed here.
- **21 foreground/background checks pass 4.5:1**; overall minimum **5.47:1**.
  Welcome body text against a conservatively rounded-up shader RGB bound is
  **6.45:1**; preview text **10.32:1**.
- Six non-text boundary pairs pass 3:1, minimum **3.40:1**. Field, dropdown and
  popup outlines were strengthened within the existing blue palette. Focus rings
  remain pale blue; checkbox and radio states also have visible shapes.
- Inspected the real 1280 x 800 VM display and an 880 x 620 application window.
  At the minimum, stacked content scrolls to the preview notice while the step
  header and actions remain visible. The larger composition shows the notice.
- Both running disposable Live previews received the installer UI files. This is
  a source preview layered on the previous ISO, not a new ISO build.
- On the fresh UEFI Live VM, 2 vCPU, 3 GiB RAM, VMSVGA/3D, no hard disk: six samples
  five seconds apart, installer open and settled, peak used memory
  **1,211,691,008 bytes**, swap **0**. Used means MemTotal minus MemAvailable.
  Installer idle CPU was **0.04% of one core over 25 seconds**; process RSS was
  **454,737,920 bytes**. RSS is not added to total used memory.
- The older, long-running preview with additional test/package/source files in its
  RAM overlay peaked at **2,127,470,592 bytes**, swap **0**, six samples with the
  installer open. These environments are not a controlled before/after comparison.

## Antislop delivery gate

| Gate | Result |
| --- | --- |
| Design Read and dials | PASS: explicit owner reference; ENERGY 2 / RHYTHM 2 / MOTION 3 recorded in DESIGN.md. |
| Intentional composition | PASS: stage progress, setup introduction, decision summaries, preview limitation and fixed actions each have a job. |
| Identity and palette | PASS: existing navy/pale blue; warm preview notice; no fabricated release badge or new logo. |
| Cards and illustration | PASS: explicitly requested reference composition; two meaningful feature rows with native outline icons. |
| Motion | PASS: native shader compiled, finite arrival settles, reduced motion suppresses it; no idle animation loop. |
| Typography and contrast | PASS: existing DejaVu Sans; 21 checks exceed 4.5:1, including conservative shader bounds. |
| Control boundaries | PASS: six non-text checks exceed 3:1; field/dropdown/popup edges strengthened. |
| Interaction and resilience | PASS: keyboard-capable controls, focused cancel dialog, native nine-page regression, small-window scrolling and persistent footer. |
| Completeness and truthfulness | PASS: working setup/review preview; installation explicitly unavailable, with no simulated execution or progress. |
| Evidence and scope | PASS: native screenshots/tests, named runtime and separate Live memory observations; no installed-target acceptance claim. |

Installation execution, physical GPU/backend testing and an installed-core idle
memory acceptance run remain pending. No installer disk writes, account changes
or EFI changes occurred. The next packaging action is an ISO rebuild when that
is requested; this source change already includes shader compilation and copying.

On resuming after a Windows restart, all VMs were stopped and the disposable Live
overlays had been lost. The UEFI GUI QA VM was started again and its compiled
installer preview restored from the local preview archive, without installing
packages or attaching a hard disk. Native mouse Begin setup followed by keyboard
Enter reached Connection and Location; Back returned to Welcome. The older main
preview and builder were left stopped. Font scaling at 200% and assistive-reader
output have not been validated.
