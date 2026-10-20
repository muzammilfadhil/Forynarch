# R5.9.0 screenshots

These are unedited guest framebuffer captures from the full R5.9.0 ISO,
booted in a diskless VirtualBox UEFI VM at 1920 × 1080, with 2 vCPUs,
3,072 MiB RAM and VMSVGA graphics. They show the actual image, without
mockups, compositing or the Windows host desktop.

| Capture | What it shows |
| --- | --- |
| [Desktop](r5.9.0-desktop.png) | Default navy desktop, widgets and compact panel |
| [Floating terminal](r5.9.0-terminal.png) | Optional floating workspace, native controls on the right, Zsh and Fastfetch |
| [About](r5.9.0-about.png) | OS and creator constants, Live session identity and copy-to-RAM status |
| [Control Center](r5.9.0-control-center.png) | Optional MacShell-derived Liquid Glass style with the Forynarch panel |
| [Login](r5.9.0-login.png) | Actual SDDM greeter after logout, with Forynarch public artwork and passwordless Live sign-in |
| [Live Welcome](r5.9.0-welcome.png) | Try/install prompt shown automatically after boot |
| [Installer](r5.9.0-installer.png) | Guided setup welcome; no disk changes were applied |
| [Boot menu](r5.9.0-boot-menu.png) | Adapted Particle Circle GRUB theme |

The VM has no Wi-Fi/Bluetooth passthrough, so unavailable radio hardware is
expected. No music player was running. The terminal's RAM figure is a Live VM
snapshot with an application open, **not** the installed idle-memory benchmark.
Creator attribution is intentionally public; no personal files, accounts,
network names or host UI are shown.

Upstream rendering and theme credits remain in [CREDITS.md](../../CREDITS.md),
[MacShell provenance](../../config/quickshell/forynarch/MACSHELL-SOURCES.md)
and [GRUB provenance](../../assets/grub/particle-circle-source/UPSTREAM.md).
