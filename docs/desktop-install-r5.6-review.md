# Blue Hour R5.6 display, storage and media review

This change makes display confirmation reachable after a mode change, adds a prepared-partition installation path with a standard partition editor, grants the Live account passwordless administration, and adds audio hardware profiles and bounded on-demand lyric lookup.

## Scope and dependencies

The UI changes are in `SystemPage.qml`, `DisplayModes.js`, `AudioPage.qml`, `AudioHardware.qml`, `MediaModel.qml`, and the standalone installer. Helpers and policies are in `scripts/install_layout.py`, `install-target.sh`, `forynarch-install-system.py`, `forynarch-installer-{info,review}.sh`, `forynarch-live-prepare.sh`, `forynarch-audio-hardware.py`, `forynarch-media.py`, `config/live/49-forynarch-apps.rules` and `config/zsh/90-live-tools.zsh`. Build integration stages the partition validator in the checksummed installation bundle.

Checked environment: Arch Linux kernel 7.2.11-arch1-1, Hyprland 0.56.2-4, Quickshell 0.3.2-1, Qt 6.12, PipeWire 1:1.6.9-1, WirePlumber 0.5.18-1 and VirtualBox 7.2.20. Existing Python runtime exceptions remain documented; no new developer-tool default or background daemon was added.

## Behavior

- Resolution and refresh rate are separate choices. The centered confirmation takes keyboard focus; Keep persists the mode and the independent 15-second watchdog restores an unconfirmed mode.
- Storage offers KDE Partition Manager, refresh and a dual-boot guide. Prepared installation requires a verified Linux GPT root and FAT EFI partition on the selected disk. Only root is formatted. The GPT and other volumes are retained; the shared EFI mounts at `/efi`, keeping kernel files on root. Recognized existing EFI loaders receive GRUB entries. Adding a firmware entry is an explicit option.
- The disposable Live account receives `wheel` and a Live-only NOPASSWD rule. KDE's installed authorization action is `org.kde.kpmcore.externalcommand.init`; its exact ID is allowed only for an active local Live account. The installed root has neither this Live policy nor its sudoers rule.
- Audio hardware can be switched Off and restored to an available profile. Default devices, mute/volume and per-application routing remain independent controls.
- Lyrics use embedded metadata first, otherwise metadata normalization, exact lookup and bounded search matching. Success, missing results and transient failures have distinct cache lifetimes. Lyrics disabled, a hidden widget or widget editing stops requests. Mudil selection reacts to its MPRIS playback state.

## Verification

| Check | Result |
| --- | --- |
| Arch source suite | Final run: 275 tests in 20.475 seconds; 273 passed, 2 skipped because builder lacks Node and Zsh |
| ShellCheck and Python compilation | Changed installer/Live/review/display/media scripts passed; Python helpers compiled |
| Native display flow | Real 1920×1080 → 1280×800 preview, resolution-specific refresh list, focused Keep confirmation, second preview and watchdog rollback passed |
| Standalone installer QML | Native welcome shader, finite/reduced motion, account validation, optional choices, secret isolation and modal keyboard focus passed |
| Disposable 64 GiB prepared install | Root installation completed; GPT unchanged; entire 2 GiB NTFS partition SHA-256 unchanged; three pre-existing EFI fixture files retained; previous firmware entry IDs retained; new Forynarch loader and GRUB entries verified |
| Installed separation | `/efi` fstab assignment verified; Live sudo/polkit rules absent; no default browser, Git, Node.js, npm, GCC, Docker or VS Code |
| Standard partition editor | KDE detected the QA disk's FAT32, NTFS and ext4 partitions without a Live password prompt; no queued operation was applied by this editor test |
| Native audio | Actual `pactl` card Off → Restore → original profile preserved |
| Native media fixture | Reactive Mudil choice, exactly two requested helper calls, no calls while disabled/hidden or with embedded lyrics |
| Live LRCLIB request | A metadata lookup returned an `ok` result with 49 synchronized lines; lyric text is not reproduced here |
| Final ISO cold boot | All 150 source/shader checks matched; bundle checksums, core optional-package separation and native installer QML flow passed |
| Live administration | `sudo -n` and direct `pacman`/`gdisk` Zsh wrappers passed in the final Live account |
| Installed idle gate | Six samples after five minutes with the shell ready: peak **1,218,043,904 bytes**, swap **0**; panel remained mapped after sampling |
| Installed source parity | **133 files matched** after synchronizing the read-only disk-inventory schema; no running service changed. The QA monitor was included in RAM usage and removed afterward |

The preservation fixture uses synthetic EFI loader files, not a working Windows installation. It verifies that existing bytes and layout survive installation; it does not certify Windows or BitLocker boot.

VirtualBox's direct SVGA3D Qt renderer rejected DMA-BUF attachment in the test harness. Re-running the native QML flows with the existing VM launcher setting (`LIBGL_ALWAYS_SOFTWARE=1`, OpenGL QRhi) passed, including shader compilation. Physical hardware retains its native renderer.

## Design and accessibility gates

| Gate | Evidence and limit |
| --- | --- |
| Hard | Existing navy identity and components retained; no new decorative dashboard or always-running visual effect |
| Purpose | Destructive root formatting, preserved EFI, firmware choice and unsupported layout features are stated before confirmation |
| Motion | Existing finite welcome motion and reduced-motion behavior passed the native installer fixture; mode changes prioritize a stable confirmation |
| Craft | Resolution-dependent rate choices, unavailable profile filtering, plain-text hardware labels, cache limits and useful error states are implemented |
| Accessibility | Native confirmation focus passed; hardware switches and profile choices have accessible names. Existing conservative text/background checks remain 5.06:1 and 4.72:1; this does not certify every translucent background or assistive technology |

## Remaining hardware verification

Prepared installation currently supports UEFI/GPT, ext4 root, a FAT EFI partition on the same disk, and no pre-existing `EFI/Forynarch` destination. Automatic shrinking, encrypted Linux installation, separate `/home`, BIOS installation and Secure Boot remain unsupported and are stated in the UI. Do not treat it as an automatic migration tool.

Physical resolution/refresh, multi-monitor scaling, HDMI/USB/Bluetooth audio profiles and real existing-OS boot remain untested. The earlier intermittent VirtualBox/kernel boot failure is not declared fixed. An initial installed QA login also showed a blank shell with a kernel soft-lockup report; that run was rejected as an idle-memory result.

The accepted installed run used 3 GiB RAM and two virtual CPUs. Used memory was `MemTotal - MemAvailable`, sampled six times at 10-second intervals after five minutes idle. Samples in bytes: 1,209,405,440; 1,209,671,680; 1,209,663,488; 1,218,043,904; 1,210,314,752; 1,214,509,056. These are installed-core measurements, not a Live or optional-application workload. The earlier QA monitor's startup ordering/readiness checks and result persistence were corrected before this accepted run; a previous result overwritten during recovery was excluded.

Final image: `out/iso/forynarch-2026.10.18-blue-hour-r5.6.iso`, **3,755,556,864 bytes**. SHA-256: `36c00655379e0e2003fd515ae7f54762bbf8f1e7f69820cf52c27da1ec9216ee`. The download matched the builder's checksum. This acceptance section records verification completed after image assembly; the bundled usage guides describe the implemented controls.

See [install and dual boot](wiki/install-and-dual-boot.md), [displays, audio and lyrics](wiki/displays-audio-and-lyrics.md), and the [preceding desktop review](desktop-hotfix-r5.5-review.md).
