# Blue Hour R5.5 desktop review — 18 October 2026

This change addresses the reported repeating `windows.lua` focus exception,
widget resizing, missing Fastfetch logo, Control Center hover descriptions,
and Wi-Fi controls that did not reflect the active connection.

## Changes and assumptions

- `config/hypr/windows.lua`: validate mapped/hidden state and finite geometry
  before centering the cursor. Expired Lua references return nil properties.
  Floating focus keeps the cursor in place. `at` is a valid field in the
  checked Hyprland 0.56.2 API; the photograph alone cannot establish why the
  specific reference was invalid on the physical laptop.
- `WidgetSurface.qml` sizes native surfaces from the loaded card. The music
  widget no longer animates its height independently of that surface, which
  could crop the old size during a resize. Other motion remains available.
- `config/fastfetch/config.jsonc` restores the generated Forynarch mark,
  automatic logo placement, and exactly seven information modules: OS, Host,
  Kernel, Uptime, CPU, Memory, GPU.
- `QuickControlActions.qml` and `WifiStatus.js` track reactive network properties
  and read cached NetworkManager status while Control Center is open. A native
  fixture reproduced the previous stale name when a network's `connected`
  property changed; explicit property reads corrected that binding. The fallback
  handles active SSIDs absent from the scan model and escaped separators.
- `MacControlCenter.qml`, `MacControlTile.qml`, and `NetworkPage.qml` provide
  nearby networks, scanning, connection/password prompts, and adapter diagnostics
  inside the glass panel. The round icon switches the radio; its name/chevron
  opens networks. The scanner stops when the pane closes.
- MacShell button/slider/tile tooltips and classic Control Center power/lock
  tooltips are removed. Accessible names, focus outlines, and error text remain.

Tested versions: Hyprland **0.56.2**, Quickshell **0.3.2**, Fastfetch **2.70.0**,
Linux **7.2.11-arch1-1**, Archiso **91**, VirtualBox **7.2.20** on Windows 11.
The build ran `pacman -Syu`; no package upgrades were pending. No optional
developer tools or applications were added to the installed core.

## Verification

| Check | Exact result |
| --- | --- |
| Arch Python suite | 263 run in 9.431 s; 261 passed, 2 skipped (builder lacks Node and Zsh for those checks) |
| ShellCheck | Build script, glass runner, Wi-Fi status runner, connectivity runner passed |
| Lua focus fixture | Expired/incomplete objects, hidden/unmapped/floating windows, nonfinite/zero geometry, and negative monitor coordinates passed |
| Native focus on final ISO | Tiled focus centers the cursor; floating focus and Alt+Tab preserve it |
| Native widget geometry on final ISO | All 12 combinations of classic/MacShell music, lyrics on/off, and 80/100/120% size passed width, height, and screen-bound checks |
| Wi-Fi status QML fixture on final ISO | Reactive active name, escaped SSID/profile, wired coexistence, radio off, connecting, disconnected, and fallback passed |
| Connectivity QML fixture in a native panel | Scan/discovery, sorting, password focus and clearing, enterprise routing, pairing confirmation, and scanner cleanup passed with synthetic services |
| Final ISO contents | 129 source/shader comparisons, bundle checksums, core/optional separation, plugin loading, and Hyprland config checks passed |
| MacShell glass | Final ISO reported ready/captured/liquid true and failed false |
| Installed source match | 127 source/shader files matched; Live installer/auth exceptions checked separately |

The installed measurement uses the existing disposable zero-extra UEFI install
with the matching R5.5 configuration applied. It is not a new pristine R5.5
installation. After five minutes idle, six samples ten seconds apart measured
`MemTotal - MemAvailable`: **1,215,856,640; 1,216,106,496; 1,216,098,304;
1,217,376,256; 1,213,374,464; 1,208,053,760 bytes**. Peak **1,217,376,256 bytes**,
swap **0**. The temporary QA monitor is included in those values and was removed
afterward. Login, GRUB fallback/theme, valid Hyprland configuration, absence of
Live authorization, and absence of default browsers/developer groups passed.

Five short Live samples peaked at **1,422,639,104 bytes**, swap **0**. These are
Live observations, not the installed idle-memory gate. Both VMs use 3 GB RAM
and two vCPUs. No personal disks were used.

## UI delivery gates

- **Hard — PASS within this patch:** functional controls, English shipped text,
  retained attribution, no invented data, no new default daemons or dev groups.
  Navy/dark identity and liquid glass follow the user's explicit style override.
- **Purpose — PASS:** Wi-Fi now exposes actual connection actions and states;
  empty hardware and password states have visible explanations.
- **Motion — PASS:** native-surface sizing replaces the conflicting height
  animation; playback/hover motion and reduced-motion preferences remain.
- **Craft — PASS within tested states:** glass retains its fallback background;
  the final ISO renders the panel and the widget size matrix stays in bounds.
- **Accessibility — PASS for affected controls tested:** names/focus outlines
  remain, native password focus and clearing pass, and removing tooltips does
  not remove error/status text. Contrast checker results: muted clock text
  `#9bb2ca` on `#243e57` **5.06:1**; Control Center muted text `#c5c5c9` on
  conservative base composite `#425162` **4.72:1**. This does not certify every
  shader frame, wallpaper, third-party app, or screen reader interaction.

## Artifact and remaining risks

`out/iso/forynarch-2026.10.18-blue-hour-r5.5.iso`, **3,755,556,864 bytes**.
SHA-256: `fd54f033945ab494bcb89534e393c029df9f4eaf241cc5a113ede3edd90925c5`.
The downloaded bytes matched the builder hash; a matching sidecar is included.

One initial UEFI boot in VirtualBox panicked at 11.18 seconds, before modules
were linked. Its locally decoded panic QR showed repeated `irqentry_enter`
general-protection faults and an APIC timer interrupt. An unchanged-ISO reboot
then completed and passed the desktop/content checks above. A further cold boot
also reached the Live Welcome screen after restoring the original disabled-UART
setting: two successful boots following the one failed attempt. This is an
unresolved intermittent boot failure; the stack does not prove whether the
kernel, hypervisor, or another cause is responsible. It is not attributed to
the Lua callback or declared fixed. No host Hyper-V/security settings were changed.

Physical Wi-Fi connection/reconnection and adapter-driver behavior remain
untested here: VirtualBox supplies Ethernet, not a Wi-Fi radio. The next
hardware check is to boot this ISO on the reported laptop, connect through the
Control Center, confirm the SSID, resize widgets, and exercise window focus.
The old USB session does not receive changes from the Windows checkout.

See [Wi-Fi and desktop recovery](wiki/wifi-and-desktop-recovery.md) for usage,
asset locations, and the checked primary API references. Earlier release
coverage and limitations remain in the [R5.4.1 review](release-review-2026-10-18.md).
