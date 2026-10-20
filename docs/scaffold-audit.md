# Scaffold audit and Sprint 0/M1 proposal

Audit date: 14 October 2026. Status: source inspection and design; no OS build or installation tested.

Follow-up source progress: Git has now been initialized on `main`; desktop application prototypes, separate review-only target/live package candidates, a strict optional-package preview planner with 19 passing local tests, and guarded build/evidence helpers have been added. The initial findings below describe the pre-change scaffold. See [latest local results](../tests/latest-results.md) and [latest stable Arch baseline](current-baseline.md). M0/M1 remain open pending the Arch VM and hardware gates; the desktop/installer is not complete.

Further source progress: [automated build and experimental CLI installation](automation.md) add a Windows/SSH launcher, independent core snapshot, installed-version adapter, signed optional download checks, disk-specific consent and inventory verification. Local suites now include these pure/helper contracts; actual Arch build, installer and hardware gates remain open.

## Intent and evidence

Read README, the complete vision, architecture, installer specification and roadmap before inspecting scripts, package lists, configuration placeholders and repository attributes. Preserve the user-authored vision unchanged. This audit covers the current source tree, not an installed system.

The workspace contains two Bash build helpers, three package proposal files and configuration/branding placeholders. `git status --short` reports `fatal: not a git repository`; ignore and line-ending rules exist but are not yet enforced by a repository. No usable desktop configuration, target package manifest, installer adapter or test evidence is present. The empty archiso/config/test destinations do not establish feature completion.

## Findings

| Priority | Evidence | Required action |
| --- | --- | --- |
| P0 | Desktop is a wishlist, with no independent target rootfs definition | Define target explicit packages separately from live-only packages; resolve and review their dependency closure in Arch |
| P0 | Optional catalog is design YAML; every current group is off | Preserve this contract through a version-tested installer adapter and summary; never feed development.txt into installation |
| P0 | No installed Hyprland or Calamares release is recorded | Record exact versions and use matching shipped examples before writing syntax |
| P0 | setup-profile copies upstream releng; build-iso invokes mkarchiso | Neither helper integrates the desktop or makes an installable distribution |
| P0 | Build helper checks command/profile/root but not Arch, filesystem type or output provenance | Before build use, add validated platform/filesystem guards, source provenance and build evidence; do not run on Windows or NTFS |
| P0 | No Git metadata in workspace | Initialize source tracking, inspect ignored files and create a reviewed baseline; no release claim until VM gates pass |
| P1 | Desktop wishlist omits explicit portal, polkit agent, login, lock and network UI choices | Resolve M1 session services as a coherent package set, including mandatory transitive dependencies |
| P1 | Architecture shortcut table omits two vision shortcuts | Retain directional tiled-window swapping and explicit monitor focus with cursor movement in M2 acceptance criteria |
| P1 | No package selection/dependency or offline evidence | Implement the plan in optional-installation-plan.md before enabling installer execution |
| P1 | No hardware or power measurements | Keep battery/thermal improvements as hypotheses until controlled hardware tests |

## Vision coverage and verification ownership

| Vision feature | Delivery | Minimal verification |
| --- | --- | --- |
| Navy, readable, restrained desktop; optional light theme and sound design | M1 foundation; later visual settings | Review text contrast, focus states, scaling and reduced motion on physical GPU hardware; track light theme/sounds as planned |
| Per-window toggle; workspace default; optional bulk rearrangement; remembered geometry | M2 | New-window default changes leave existing overrides intact; explicit bulk action is separate; move across scales without offscreen windows |
| Five local slots per monitor, persistent identity, hotplug, active slot and cursor focus | M2 | Two-monitor focus/move test plus unplug/replug, identity collision and fallback tests; later three-monitor expansion |
| MRU Alt+Tab, reverse, icons/previews; directional swaps; configurable shortcuts | M2 | Verify MRU order across apps/windows, reverse navigation and both omitted shortcuts; previews depend on chosen switcher |
| Launcher apps/files/commands/quick actions | M1 app launching; later launcher expansion | Launch an app in M1; later test file search scope and each quick action separately |
| Discovery, UUID aliases, shell drive shortcuts, GUI policies, encryption, eject | M5 | Disposable media tests for manual/prompt/trusted policy, encrypted unlock, label collisions and safe eject |
| NTFS/exFAT sharing, Linux-native root, optional shared partition, snapshots/rollback | M4/M5 and recovery QA | Synthetic Windows/EFI layout; hibernated/unclean NTFS denied write access; root and shared-data behavior documented |
| Wine/Bottles/Proton, executable integration, optional Windows VM | M7 | Per-app launcher/window/files/notification tests; VM resource and licensing prerequisites documented |
| Boot discovery and controlled reboot to another OS | M5/M7 | Disposable UEFI VM preserves Windows entry; confirmation and unsaved-work handling; unsupported firmware fallback |
| Eco/Balanced/Performance, AC/battery switching, thermal safety | M6 | One policy manager; measured fixed-brightness workload, suspend/resume, AC changes and supported sensors on a laptop |
| Guided/manual install, account/encryption/bootloader, cancellation and recovery | M4/M8 | Fresh disposable disks, selection matrix, offline/error cases and pre/post disk comparisons |
| Rebuildable source, supported hardware and console fallback | M0/M3/M8 | Recorded package/tool versions, clean rebuild, UEFI boot and graphical failure recovery |

All vision features remain requirements or explicitly planned work. M1 is a developer preview, not the vision's first usable release: that release also requires hybrid workspaces, storage safety, power integration and rebuild evidence.

## Sprint 0 architecture and exit gate

1. Keep Windows as the authoring host. Establish Git source tracking with existing LF/ignore rules; review licensing separately before publishing.
2. Prepare an Arch x86_64 VM on its native filesystem. Record kernel, archiso, Hyprland, pacman and later Calamares versions, upstream template revision, repository snapshot/mirror date and graphics backend.
3. Define three package boundaries: reviewed target core, live-only installer/recovery additions, and optional groups. Keep desktop.txt and development.txt as proposals until package names and dependencies are validated.
4. Choose a minimal login path and graphical stack from installed-version documentation. Use a console login during the first prototype; retain a TTY fallback. No autologin or user creation is assumed.
5. Record test results by environment using tests/verification-plan.md. Sprint 0 remains open until Git baseline and Arch VM evidence exist.

## M1 architecture and exit gate

Hyprland owns windows/rendering. Waybar displays state; Foot and Fuzzel provide terminal/app access. Thunar uses GVfs/UDisks2 with polkit for authorized storage actions. NetworkManager supplies connectivity; select a lightweight supported Wi-Fi UI. PipeWire/WirePlumber supply audio. Choose compatible portals, a polkit agent, notification service, fonts, screenshot/clipboard utilities and lock/idle integration after dependency review.

Use packaged components before custom services. Prefer compositor-native M2 functionality; only add a small event coordinator if installed APIs cannot apply future-window preferences safely. The coordinator must not require Git, Node/npm or Python as an explicit development selection. Any unavoidable runtime dependency needs package-chain evidence and disclosure.

M1 order: terminal/session and recovery, launcher/bar/file manager, network/audio/polkit/portals, lock/logout/suspend, then navy styling and reduced motion. Store modular configuration in config/ only after its version is known. Verify login, terminal, app launch, files, Wi-Fi, sound, screen lock, portal use, logout and suspend/resume on supported physical graphics hardware.

## Assumptions and limits

No Arch VM or installed release was supplied. Exact Hyprland syntax, Calamares schema, bootloader, root filesystem and power manager remain version/hardware decisions. The upstream Archiso profile reference was accessible; the Arch Wiki returned access denial, Hyprland homepage timed out and the attempted Calamares module page could not be fetched. No syntax is inferred from those failed fetches.

Reference: [official Archiso profile specification](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst) describes profile package lists and image overlays; this supports treating the releng helper as live-image preparation only. [Calamares documentation](https://calamares.codeberg.page/) remains the installer entry point; use a pinned release's shipped module examples for implementation.

Next smallest action: capture versions and dependency closure on an existing Arch VM, without installing packages or changing accounts/disks until those operations are explicitly approved.
