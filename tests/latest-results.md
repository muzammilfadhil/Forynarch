# Installed patch R5.8.8 - 20 October 2026

Eight titlebar policy tests passed on Windows and Arch. Three affected Bash
scripts and four Python sources passed syntax checks. The native damage patch
built against Hyprland 0.56.2-4 and passed idempotence; upstream compiler
deprecation/narrowing warnings remain. Live R5.8.7 -> R5.8.8 configuration
upgrade and fresh-session native loading passed with empty config errors.

Native class fixtures confirmed Chrome/Discord default exclusions and retained
external bars for frameless web apps, including Chrome-prefixed classes. Live
override/reset, global off/on and custom-class persistence passed. The full
Settings page loaded; an actual pointer toggle persisted the Discord override.
The new input placeholder/border/focus contrast ratios are 6.16:1, 3.95:1 and
10.47:1 against the field background.

Eighteen native compositor moves, resize and minimize with 40 px corners kept
the probe floating. The cleared static region [300,180,1500,1000] exactly
matched a temporary full-redraw reference: 984,000 pixels, zero differences.
Damage tracking was restored to 2. This was software-rendered VirtualBox,
not the user's physical GPU, and no unpatched before/after reproduction or
installed idle-memory measurement is claimed.

Physical pointer dragging and injected keyboard entry did not validate in
this fixture; existing Settings search also showed no injected text. Native
movement dispatchers and pointer toggles passed. The updated shell used the
existing VM SHM fallback; source-tree motion shader .qsb files were absent,
so that source-only motion preview was not validated. The patch does not
replace the installed compiled shader assets. [Installation, limits and
restore](../docs/installed-patch-r5.8.8.md). No ISO build or package install.

# Installed patch R5.8.7 - 19 October 2026

11 media tests passed on Windows. Six identity/favicon tests passed on Arch
(Windows: five passed, one symlink test skipped); three isolated web-app shell
tests passed. Native Quickshell media flow passed with exactly two timed lyric
lookups, embedded LRC offset parsing, forward/backward lyric selection,
pause/seek, player switch, track reset and no requests when disabled/hidden.
A real private D-Bus test of the vendored Dart bridge passed advancing Position,
frozen pause, Seeked signals, 2x rate and reset. Flutter release build completed;
native package metadata and every archive install path passed validation.

Desktop-only patch apply passed in the diskless VirtualBox fixture, with empty
Hyprland configuration errors. Native titlebars rendered the configured
`Work mail` name instead of the URL and excluded the Mudil class. The updated
full shell loaded; the Mudil logo rendered from its absolute native icon path.
Four affected Bash scripts passed syntax checks; the pinned Hyprbars source
patch passed a second, idempotent application. Native build retained upstream
deprecation/narrowing warnings. VirtualBox used the existing SHM buffer fallback.

The older Live fixture lacks `mpv`; its normal package-install attempt correctly
refused the missing dependency. An extracted Mudil launch likewise stopped at
missing libmpv. Actual account playback and installed-package upgrade on the
user's hardware remain acceptance checks; they are not reported as passed.
Existing installed Mudil already declares mpv as a dependency. No ISO built,
no personal disks touched, and no new installed idle RAM benchmark claimed.
[Patch, installation and restore](../docs/installed-patch-r5.8.7.md).

# Installed patch R5.8.6 - 19 October 2026

18 storage tests passed. Native VM flows passed music timeline binding and
masked drive input. Actual titlebar clicks passed minimize/maximize/fullscreen/
close; restore passed through the existing helper. Desktop-only apply and
file-by-file rollback passed (9 user, 16 system files). Kath lock acquired the
secure protocol in the VM with the screencopy fade workaround. Hardware audio,
real BitLocker unlock and Chrome/yay AUR installation remain user-session
acceptance. No ISO built. [Details](../docs/installed-patch-r5.8.6.md).

# Installer R5.8.5 - 19 October 2026

Bash syntax, ShellCheck and the focused Flatpak retry test passed. The disposable
overlay reproduced the supplied chroot namespace error; the replacement runner
executed real nested bubblewrap successfully as a user with zero effective
capabilities and no-new-privileges. Preflight passed and the host namespace
sysctl was unchanged. No complete Flatpak application install or physical
installation was repeated. Details: [R5.8.5 review](../docs/installer-r5.8.5-review.md).

Final ISO source checks: 14 Live files, 11 target-bundle files and four
namespace executables passed. Core: 573 packages, no unselected developer
packages. Builder/Windows ISO checksums matched.

# Network speed-test button R5.8.4 - 19 October 2026

Scoped verification only: actual Network settings UI rendered the new action in
Live; whitespace check passed. No full regression suite, browser launch test or
throughput measurement was run. Final artifact hashes matched 14 Live and 11
target-bundle source files. Core remains 573 packages without unselected developer
groups. ISO checksum matched on builder and Windows. Details:
[R5.8.4 review](../docs/network-speedtest-r5.8.4-review.md).

# Panel and battery R5.8.3 - 19 October 2026

11 battery telemetry tests passed on Windows and Arch; 17 existing Arch system
settings tests passed. Native Wayland covers every panel toggle, empty-group
restoration, battery watts/time/unavailable fields, popup settings/close and
no-battery behavior. Existing layout tests passed 100 permutations and 20 metric
boundaries. Bash syntax and ShellCheck passed. Details and hardware limits:
[R5.8.3 review](../docs/panel-battery-r5.8.3-review.md).
Both bar styles passed at 800/1024/1280 pixels. Preference persistence passed
a real shell restart. Final ISO UEFI boot, battery popup and Live helper probes
passed; 13 Live source hashes and 10 target-bundle hashes matched. Core: 573
packages, no unselected developer groups. ISO SHA-256:
`8c985aa2c7df4936fa87fb2a3cce5dbba6d21b060be65410768abc095fcae899`.


# Installer R5.8.2 - 19 October 2026

57 targeted tests passed; Bash syntax, ShellCheck and whitespace checks passed.
The 17 executor tests also passed with a forced ASCII caller locale. The actual
CLI completed a 32 GiB disposable loop installation with selected Git: exit 0,
all stages through complete, 60.47 seconds, 578 packages. Read-only postchecks
confirmed boot artifacts, the /efi mount, explicit Git, no unselected developer
packages and no Live sudo leak. No personal disk or firmware entry was written.

The supplied log exposed a false package-plan change: pacman's download size
becomes zero after caching. The recheck now compares name, version and SHA-256.
A real Git reproducer and a local-repository regression cover this boundary.

Native UI fixtures passed live log viewing while busy, pause/resume, real clipboard
copy, locked navigation, completion and failure/interruption states. The full log
stays on disk; the viewer uses bounded, throttled, sanitized push updates.
Dedicated-disk kernel files now remain on ext4 with the ESP at /efi, avoiding the
FAT32 ACL failure found by the full CLI test. Hardware and full Flatpak acceptance
remain separate. Details: [R5.8.2 review](../docs/installer-r5.8.2-review.md).

# Installer R5.8.1 - 19 October 2026

54 targeted tests passed; Bash syntax, ShellCheck and whitespace checks passed.
The 15 executor tests additionally passed in forced ASCII locale with UTF-8 mode
and locale coercion disabled. Native Wayland fixtures passed normal completion,
download/Flatpak failure and helper interruption with unknown disk state.

The previous R5.8 helper reproduced the screenshot's missing-report state on
non-UTF-8 child output: UnicodeDecodeError, last stage download, no terminal report.
The hotfix explicitly decodes output, preserves strict UTF-8 account input, keeps
collecting the child result if log/status writes fail, and fixes unknown-state UI.
Physical-laptop logs were unavailable, so the matching reproducer does not prove
that byte corruption was the only cause on that laptop.
Final ISO: 3,839,197,184 bytes; host/builder SHA-256:
`cbd6d80911a403825a3cafd54d26e6a9e18861b7d102f2b8b7feb624900b57d8`.
Final-image source hashes, UEFI Live boot, executor discovery and the actual
Live helper under an ASCII locale passed. Core remains 573 packages.
Details: [R5.8.1 review](../docs/installer-r5.8.1-review.md).

# Installer R5.8 - 19 October 2026

50 targeted tests passed; Bash syntax and ShellCheck passed. Native Wayland
fixtures passed setup, successful execution, pre-write download failure and
post-write Flatpak failure, including diagnostic controls and unknown disk state.

The laptop selection resolves to 196 repository packages. All downloaded and
verified; the previous filename guard rejected 15 legitimate epoch filenames.
The patched guard accepts them. Repository selections plus Mudil Music installed
in an isolated rootfs: 770 packages, matching exact inventory and explicit reasons.
The independent core remains unchanged. No real block devices were written.

The first full Flatpak attempt failed on transient DNS. A smaller extension then
installed with the unchanged resolver. The full three-app runtime download was
stopped to complete the installer image; full Flatpak app acceptance remains open.
Final R5.8 image: 3,839,197,184 bytes; builder/host SHA-256 matched:
`32d075b97aac797f9ed9c142414451e74967a9d79e1b51178a0ccfd0a96331a4`.
SquashFS contains the verified installer sources; the independent payload retains
573 core packages without the optional QA selections. The final ISO booted via
UEFI to the Live desktop and Try/Install Welcome; actual Live source hashes and
executor discovery passed, with no target disk attached.
See [R5.8 review](../docs/installer-r5.8-review.md) for details and limitations.

# Installer R5.7 - 18 October 2026

46 targeted installer/partition tests passed (34 + 12); ShellCheck passed.
Native Wayland setup and fake-executor QML fixtures passed. A real offline
prepared-root reinstall on the disposable 64 GiB fixture completed with 573
core packages, identical GPT/NTFS data, preserved other EFI files and a backup
of the previous Forynarch loader. Firmware was unchanged with registration off.
An independent VM configuration booted the installed clone to SDDM and the
Hyprland desktop; the old VM frontend's startup abort remains a host/configuration
issue. No physical GPU/storage acceptance or new idle-memory benchmark is claimed.
Final image SHA-256: `7f694549d178cd4cb376e9c225fde167141fb353a296f70dfe1cf216c8ea66cd`.
Details: [installer review](../docs/installer-r5.7-review.md).

# Local verification — 18 October 2026

Blue Hour R5.6: **275 Arch source tests run, 273 passed, 2 skipped** in
20.475 seconds in the final run. Native display preview/keep/rollback, standalone installer QML,
audio hardware Off/Restore and on-demand media fixtures passed. A real
prepared-partition installation on a disposable 64 GiB disk retained GPT,
the entire NTFS fixture and existing EFI files. See the
[R5.6 review](../docs/desktop-install-r5.6-review.md) for scope and limitations.
The final ISO matched **150 source/shader files**. The installed fixture
matched **133 files**; six samples after five minutes idle peaked at
**1,218,043,904 used bytes**, swap **0**, with the panel still ready afterward.
The initial blank-desktop run and an overwritten QA report are excluded.
Earlier R5.5 results below are historical.

Blue Hour R5.5: **263 Arch source tests run, 261 passed, 2 skipped**.
The Lua lifetime/geometry fixture, native focus behavior, all 12 widget
style/lyrics/scale combinations, reactive Wi-Fi status, and panel connection
fixtures passed. The final ISO matched **129 source/shader files** and passed
bundle/core separation checks. The installed fixture matched **127 files**;
six samples after five minutes idle peaked at **1,217,376,256 used bytes**, swap
**0**. Five short Live samples peaked at **1,422,639,104 bytes**, swap **0**.

One initial VirtualBox boot panicked before modules loaded; an unchanged-ISO
reboot and a further cold boot passed. Physical Wi-Fi and the cause of that intermittent panic remain
unverified. See the [R5.5 review and remaining risks](../docs/desktop-hotfix-r5.5-review.md).

## Previous verification — Blue Hour R5.4.1

Blue Hour R5.4.1: **263 Arch source tests run, 261 passed, 2 skipped**.
ShellCheck and GRUB syntax checks passed. The final ISO passed UEFI Particle
Circle boot, 128 source-file comparisons, bundle checksums, core/optional
separation, native audio-route tests and connectivity fixtures. Five Live RAM
samples peaked at **1,488,998,400 bytes**, swap **0**; this is not an installed
benchmark. See the [complete review and limitations](../docs/release-review-2026-10-18.md).

The zero-extra offline dedicated-disk install passed GRUB EFI boot and Kath
passwordless sign-in. After the matching glass correction, the installed core
peaked at **1,354,928,128 used bytes**, swap **0**, across six samples after
five minutes idle. The temporary QA monitor was included and then removed;
126 installed source/shader files matched the final manifest.

## Earlier verification — 15 October 2026

**Hybrid/floating follow-up:** **129 Arch tests passed** (`3.830s`, no skips),
Bash/ShellCheck and Archiso policy gates passed. Native window tests verify
hybrid main/utility defaults, size presets, explicit fit, preservation of
existing window sizes, manual overrides and the lock timeout. Popup-focus tests
pass with the updated Settings UI. Native File Manager CSD controls were checked
in a separate Live VM. See the [window review](../docs/hybrid-floating-windows.md).

**Blue Hour implementation:** Arch source tests **129 passed** (`2.836s`, no
skips); Bash, ShellCheck and Archiso 91 boot-policy gates passed. Native emoji,
widget editor, Cava/MPRIS, window modes, popup focus and installer fixtures
passed. A real zero-extra offline graphical install booted its EFI target and
logged in through Kath SDDM. Installed core after five minutes idle peaked at
**1,224,302,592 bytes**, swap **0**, over six samples on the initial candidate.
The final R1 ISO independently passed cold boot, passwordless offline graphical
installation and installed EFI boot without manual repairs. Its separate
five-minute idle run peaked at **1,195,581,440 bytes**, swap **0**, over six samples.
See the [complete review and limitations](../docs/production-desktop-review-2026-10-15.md).

Earlier records follow.

**Latest Kath video update:** supplied MP4 is now the default. Native playback,
looping and missing-source failure fixture passes. Arch **104 tests passed**
(`2.411s`, no skips), Bash/ShellCheck pass. Live desktop plus portable greeter
peaked at **1,573,588,992 bytes**, swap **0**; greeter RSS **355,061,760 bytes**.
Software-rendered video/blur CPU was **111.56% of one core over 25s**; physical
GPU power use and installed-core RAM remain untested. No new ISO.
See the [video review](../docs/kath-video-review.md).

**Earlier connectivity and static Kath source preview:** Arch builder **104 tests passed**
(`1.716s`, no skips), Windows **56 passed / 48 Linux-only skips** (`2.340s`),
and Bash/ShellCheck gates pass. Three native QML fixtures pass connectivity,
inert login power actions and settings feedback. Actual SDDM test-mode preview
renders the static Kath adaptation with a fading local blur.
Live desktop plus portable greeter peaked at **1,273,245,696 bytes**, swap **0**;
greeter RSS **251,043,840 bytes**, sampled CPU **0.04% of one core over 25s**.
The disabled-input preview is not an authentication lifecycle benchmark.
Bluetooth pairing helper
compilation, real login/power actions, installed RAM acceptance and a rebuilt
ISO remain pending. See the [current review](../docs/connectivity-and-kath-review.md).

**Earlier source preview:** the screenshot-directed installer style adds a bounded
blue-fold shader, finite motion and reduced-motion controls. Arch Live **101 tests
passed** (`1.810s`, no skips); native QML shader/wizard regressions and builder
ShellCheck pass. Six samples with the installer open on the fresh Live VM peaked
at **1,211,691,008 bytes**, swap **0**; installed-target acceptance remains pending.
See the [current UI review](../docs/installer-reference-style.md). This revision
has not been rebuilt into an ISO.

**Earlier ISO rebuild completed:** Glass ISO **3,653,664,768 bytes**, builder and Windows
SHA-256 match. Builder **101 tests passed** (`1.207s`, no skips), Bash/ShellCheck
gates passed, mkarchiso exited 0. Fresh UEFI boot with VMSVGA/3D reached the normal
Live desktop and opened the standalone installer Welcome directly from the ISO.
No hard disk was attached; installation remained disabled. See the
[rebuild record](../docs/rebuild-2026-10-15.md) for checksum, package audit,
no-3D test limitation and remaining acceptance.

Standalone installer and antislop UI revision: **101 tests passed on Arch Live**
(`1.702s`, no skips), Windows Check **53 passed / 48 Linux-only skips** (`1.984s`,
exit 0). Native real-QML tests pass for all nine pages, account validation,
password isolation, optional software/driver controls, inventory error/retry,
empty storage, symmetric account fields, non-executable review and modal focus.
Native mouse/keyboard traversal and 880 x 620 bounds were inspected. Builder
ShellCheck 0.11.0 exited 0 without findings. Fifteen contrast pairs all exceed
4.5:1 (minimum **5.47:1**). Six post-close Live samples peaked at
**1,915,813,888 bytes**, swap **0**, collector exit 0; not installed-target
acceptance. No package installs, disk writes or ISO rebuild in this UI revision.
See [delivery review](../docs/installer-ui-review.md) for scope and limitations.

Advanced partition editor follow-up: Arch Live **94 tests passed** (`1.479s`,
`OK`), including four new launcher boundary tests. Windows Check: **53 passed /
41 Linux-only skips** (`1.923s`, exit 0). Builder ShellCheck 0.11.0: no findings,
exit 0. Actual Storage button launched KDE Partition Manager **26.08.2-1**;
navy stylesheet and visible native window inspected. Native privileged device
discovery awaits administrator authentication; no partition operation was queued
or applied. The Live-only package installation added 34 packages without new
Git/Node/npm/Python dependencies. Cowspace limit increased in RAM only. After
closing Settings/editor, six Live samples peaked at **1,910,747,136 bytes**, swap
**0**, collector exit 0. This is not an installed-target memory acceptance test.
The final launcher/theme patch was followed by the 94-test native run and builder
ShellCheck; the Windows result predates that small patch. Existing ISO unchanged.

Earlier audio/storage preparation results follow:

Audio/storage preparation: **90 tests passed on Arch Live** (`1.635s`, `OK`).
Windows Check exited 0: **53 passed / 37 Linux-only skips** (`2.379s`). Builder
ShellCheck 0.11.0 reported no findings. Native QML Settings feedback regression
passed: successful CLI stdout is hidden and failures remain visible. GUI audio
tests changed virtual input/output defaults and volume/mute, then restored
original defaults and removed the virtual devices. Storage discovery and
Method → Software → Review passed with a non-executable plan and no selected
extras. The current preview is legacy-booted with a roughly 22.75 GB virtual
disk; UEFI/GPT/ESP/space checks correctly block its alongside proposal. No disk
writes, EFI/account changes or package installs were performed for this task.
Six post-close Live samples five seconds apart peaked at **1,421,119,488 bytes**,
swap 0, collector exit 0; installed idle acceptance remains pending.
See [storage and installer preparation](../docs/storage-and-installation-preparation.md)
and [audio follow-up](../docs/settings-and-hotkeys.md).

Settings/hotkeys: **78 tests passed on Arch Live** (`Ran 78 tests in 1.653s`,
`OK`). Windows Check exited 0: **53 passed, 25 Linux-only skips** (`1.980s`). Native
ShellCheck 0.11.0 reported no findings. Hyprland reload returned 0 with empty
configerrors; Glass cold-loaded all 13 pages. Keyboard Super+Ctrl+D opened
Displays. FPS diagnostic toggled on/off with boolean readback. A same-mode
display preview automatically reverted after Settings closed. Short guest
memory peak: **1,582,882,816 bytes**, swap 0, six samples/five-second intervals,
collector exit 0. NetworkManager/BlueZ/hardware, real sleep, physical multi-monitor
and installed-target acceptance remain pending; the ISO is unchanged. See
[settings implementation and research](../docs/settings-and-hotkeys.md).

Native glass/controls follow-up: **64 tests passed on Arch Live** (`Ran 64 tests
in 3.912s`, `OK`). Windows Check exited 0: 50 passed, 14 Linux-only tests skipped
(`Ran 64 tests in 4.055s`). Native ShellCheck reported no findings; Foot config
check exited 0. Actual GTK 3 transparency, Trash actions, confirmation-dialog
styling, Settings app launch, storage keywords and native opacity roundtrip
were checked. Short guest RAM peak: 1,583,620,096 bytes, swap 0, collector exit 0.
See [Native application glass](../docs/native-application-glass.md) for runtime
scope, remaining toolkit/hardware checks and the unchanged ISO status.

Files/storage iteration: **62 tests passed on Arch Live** (`Ran 62 tests in
0.787s`, `OK`). Windows Check exited 0: **48 passed, 14 Linux-only storage tests
skipped**; Bash syntax checks and pipeline plan passed. Native ShellCheck 0.11.0
reported no findings across all shell scripts. The Windows exporter parsed and
ran successfully, exporting four GPT drive letters without changing disks.
GSettings overrides compiled with `--strict`; fresh Thunar rendered the navy
stylesheet and original folder icons. Final Quickshell cold load succeeded.
Actual discovery returned zero available data volumes. A separate synthetic UI
verified C:/D:/H: cards and locked status with all fixture disk actions disabled.
No real NTFS/exFAT mount or file read was tested. Details and remaining gates:
[Blue Hour files and Windows drives](../docs/files-and-windows-drives.md).

Short Live RAM check with This Computer and the new Thunar preview open: six
samples, nominal five-second interval, peak **1,882,103,808 bytes (1.882 GB
decimal)**, swap 0, collector exit 0. Metric: `MemTotal - MemAvailable` for the
whole guest, including retained apps and isolated preview services. Raw log:
`out/virtualbox/files-storage-memory.txt`. This is not installed-target idle
acceptance. No updated ISO was built.

Previous shell iteration: **48 unit tests passed** on Windows and Arch Live.
Windows Check exited 0; Bash syntax checks and pipeline plan passed. Native
ShellCheck 0.11.0 exited 0, including a final recheck of `forynarch.sh`.
Quickshell loaded the final QML scroll fix successfully. Mouse, keyboard,
widget persistence, compiled shaders and short guest RAM measurements are
recorded in [Search, widgets and motion](../docs/search-widgets-motion.md).
The existing ISO has not been rebuilt with this desktop. The older records
below describe earlier milestones, not the current runtime state.

VirtualBox preparation follow-up: helper Prepare, VerifySignature and Start completed successfully using installed VirtualBox 7.2.20. Official Arch 2026.10.01 ISO passed published SHA-256 and GPG/WKD verification. The new 8 GiB/4-CPU VM booted into Arch Live (kernel 7.2.7-arch1-1). VBox storage inspection confirmed one new 80 GiB VDI and the ISO; guest lsblk showed the disk with no partitions/filesystem and no mount. Details: [VirtualBox builder](../docs/virtualbox-builder.md).

Source checks after adding the VirtualBox helper/bootstrap: 41 tests passed (`Ran 41 tests in 0.447s`, `OK`); Windows Check exited 0; all nine Bash files parsed; the new PowerShell helper passed AST parsing. Builder provisioning, package/account/sudo/EFI changes and disk formatting have not run and await explicit approval. Generated ISO/VDI/screenshots/keyring/runtime state remain ignored.

Latest follow-up: the automation suite now has **41 passing tests**. `powershell -NoProfile -File scripts/forynarch.ps1 -Action Check` also exited 0, running the suites, all eight Bash syntax checks and the non-mutating pipeline plan. The PowerShell launcher parsed without errors. The official v0.56.2 Hyprland example matched the adapter's structural expectations in memory; no runtime configuration was written from that check.

Added coverage: archive traversal/symlink/device rejection, core input validation, installed-example version/shape rejection, exact package inventory matching, GPT disk/type validation and nonprivileged CLI/approval boundaries. The earlier 19-test record below is retained as the initial planner evidence.

No Arch package installation, ISO build, partitioning, formatting, account creation or EFI operation was executed. Eight-script Bash syntax validation is not shellcheck or a disk-safety test. The new pipeline/installer remains experimental until the [automation QA workflow](../docs/automation.md) passes on disposable Arch VMs and suitable hardware.

Environment: Windows authoring workspace, Python 3.15.0 via `py -3`, Git for Windows Bash. No Arch VM/WSL installation was available. No packages were installed.

| Command/check | Exact result |
| --- | --- |
| `py -3 -m unittest discover -s tests -p 'test_*.py'` | Exit 0; `Ran 19 tests in 0.107s`; `OK` |
| `bash -n` invoked separately for arch-environment.sh, setup-profile.sh, build-iso.sh and record-build-environment.sh | All four exit 0 |
| Execute setup-profile.sh, build-iso.sh and record-build-environment.sh through Git Bash on Windows | All three exit 1 with the Arch Linux x86_64 VM guard; mkarchiso was never reached |
| Parse Foot/Fuzzel with configparser and Waybar with json | Exit 0; structural parsing passed, not installed-application validation |
| PowerShell local Markdown destination scan | Final check exit 0; all local links in 14 Markdown files resolved |
| `git check-ignore` for work/check.iso, out/check.iso, test.qcow2, .env and id_ed25519 | Exit 0; all five paths ignored |
| Inspect work/ and out/ after guard tests | Only existing .gitkeep placeholders; no build output |
| Git baseline preparation | `main` initialized; source staged; five entry/helper scripts recorded as mode 100755. No commit: author identity is not configured |
| `git diff --cached --check` | Initial warnings were existing Markdown hard line breaks; Markdown attributes preserve these intentionally. Recheck after the attribute update passed |

The 19 planner tests cover empty selection, the Git/JS/Python/combined matrix, all eleven explicit groups, deduplication, offline behavior, unknown choices, default/policy/schema rejection, malformed/duplicate catalog keys, package input validation, JS pairing, catalog identity and CLI failures. Planning does not execute packages and every result forbids execution.

Not tested: shellcheck (unavailable), native-filesystem/symlink guards inside Arch, actual mkarchiso operation, package names/dependency closure/signatures, application config semantics, graphics/login/lock/portals, monitor controller, target rootfs, Calamares or installer disk operations. These require the environments and approvals described in [verification-plan.md](verification-plan.md) and [current-baseline.md](../docs/current-baseline.md).
