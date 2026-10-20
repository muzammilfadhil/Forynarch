# Forynarch wiki

This Markdown wiki documents the current implementation. Features marked as
pending are not release promises. All shipped system UI uses English.

| Topic | Contents |
| --- | --- |
| [Customize your desktop](customization.md) | Appearance, motion, shortcuts, layouts and saved settings |
| [Smart window layouts](smart-window-layouts.md) | Linked snaps, shared resizing, tiling, restore and floating focus |
| [Create and share widget packs](widget-packs.md) | Import/export, the JSON format, examples and limits |
| [Boot, Welcome and login](boot-and-login.md) | Boot splash, Live installation guidance and logout |
| [Particle Circle GRUB](../grub-particle-circle.md) | Boot menu, graphics fallback, diagnostic entry and licensing |
| [Wallpaper, sound and Bluetooth](../wallpaper-audio-and-bluetooth.md) | Working wallpaper action, per-app input/output, compact audio panel and radio recovery |
| [Wi-Fi and desktop recovery](wifi-and-desktop-recovery.md) | Control Center scanning, live connection status, widget sizing, Fastfetch logo and focus errors |
| [Install and dual boot](install-and-dual-boot.md) | KDE Partition Manager, prepared root/EFI assignment, preservation and Live administration |
| [Displays, audio and lyrics](displays-audio-and-lyrics.md) | Resolution preview, audio hardware profiles and on-demand lyric lookup |
| [Logo and desktop identity](branding.md) | Logo source, replacing it and compositor startup branding |
| [Build and verify](build-and-test.md) | Windows workspace, Arch builder, tests and memory measurements |
| [Default apps and terminal](default-apps-and-terminal.md) | Application associations, Zsh, autosuggestions and fastfetch |
| [Screenshots, clipboard and music](screenshots-clipboard-and-media.md) | Capture shortcuts, private history, Mudil Music, lyrics and optional MacShell style |
| [Credits and licensing](credits.md) | Upstream code, artwork, references and unresolved licensing |
| [Storage and installation](../standalone-installer.md) | Guided setup, storage review and software choices |
| [Windows VM and BitLocker](existing-os-and-bitlocker.md) | Recovery workflow, per-profile resources, network/audio and preview limits |
| [Widget colors and identity](../widget-colors-and-identity.md) | Shared palette, window buttons and fixed About identity |
| [Keyboard shortcuts](../settings-and-hotkeys.md) | Defaults, changes and conflict detection |

Start with [the project vision](../vision.md) and [architecture](../architecture.md)
when contributing. The independent installed root filesystem must remain separate
from the Live image. Developer tools and browsers are opt-in during installation.

See [Panel, windows, sound and time](panel-audio-and-time.md) for the current panel, snap, mixer and clock controls.

See [Notifications and background apps](notifications-and-background-apps.md) for
the compact tray, notification center, DND and custom focus profiles.

See [Experimental virtual machines](experimental-virtual-machines.md) for optional
existing-OS virtualization, Preview and Direct modes, and current limitations.

See [Window controls, focus and desktop shortcuts](window-controls.md) for fullscreen, minimization, cursor behavior, outline settings and separate audio controls.

- [Panel components and battery power](panel-and-battery.md): choose visible bar buttons and inspect charging/discharging watts.
