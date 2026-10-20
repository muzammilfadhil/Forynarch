# Blue Hour R4.4 verification — 16 October 2026

R4.4 uses the owner's four-point blue spark consistently on boot, login and the
desktop launcher. Its master and reference are documented in the
[branding guide](wiki/branding.md). The former F-shaped boot placeholder is gone.
Release metadata identifies Forynarch and retains Arch as its base. Explicit
Hyprland identity settings disable upstream default branding and random quotes.

The Kath login now has a smaller clock, aligned credential fields, bounded neon
focus feedback, flat power actions and short entrance/interaction motion. Reduced
motion uses the static PNG without loading Qt Multimedia. See the
[login checks](login-neon-review.md).

Terminal shortcuts use the pointed or focused Foot shell's local directory,
including `cd` and paths with spaces. No resident process is added. Widget QML
and JavaScript remain freely editable; data-only pack import/export is separate
from unrestricted local code editing. Desktop application shortcuts stay off by
default and retain selection when hidden.

## Executed checks

- Native Arch: **171 tests passed**, no skips, **7.834 seconds**. Managed hotkey
  generation, Bash syntax and ShellCheck passed.
- Real Foot: opening another terminal inherited the changed shell directory,
  including spaces, rather than the terminal process's original directory.
- Real Hyprland 0.56.2-4: both branding-disable options returned `true`; the
  default-wallpaper choice returned `0`; no compositor configuration errors.
- Inert login harness: all four power mappings, unavailable capability checks,
  cancellation and initial Cancel focus passed without executing real actions.
- Real greeter: Enter signed into the passwordless account; username editing
  retained focus and revealed the password field for a different account.
  Reduced-motion screenshots were identical and Qt Multimedia was not loaded.
- Text contrast: **11.05:1** for sign-in text and **9.39:1** for supporting text.
- Exact R4.4 ISO: cold UEFI boot showed the spark, moving dots, progress and
  status description, then Live Welcome. Plymouth exited. The Live root reported
  `ID=forynarch`, `LOGO=forynarch` and `IMAGE_VERSION=2026.10.16`.
- Exact R4.4 ISO: enabled a File Manager desktop shortcut, launched it by double
  click, disabled shortcuts again and verified selection remained in preferences.
- Exact R4.4 ISO: logout returned to the new Kath greeter and Enter started a new
  session. File Manager was closed, the shortcut preference remained disabled,
  and the source-folder helper exposed all 13 editable QML/JavaScript entries.
- Host and builder ISO SHA-256 matched:
  `41dd9ba9cf979fd489d1522440b9e76df6cdb17546e51dc2530a5ddc0036c2cd`.

## Memory and limits

The R4.3 installed core, after five idle minutes with no application windows,
measured six samples of `MemTotal - MemAvailable`: 1,235,828,736;
1,235,935,232; 1,235,959,808; 1,238,233,088; 1,246,621,696;
1,246,883,840 bytes. Peak **1.247 GB decimal**, swap **0**. Blur, motion and four
default widgets were enabled; optional desktop shortcuts and custom packs were
disabled. This is the installed baseline, not a Live or builder reading.

R4.4 installed memory has not been remeasured. Its logo, terminal helper and
greeter changes do not justify presenting R4.3's number as a new result. Complete
the installed cold-boot memory matrix before a release claim. Physical GPU
handoff, mixed-scale monitors, sleep/hibernate, Wi-Fi/Bluetooth hardware, low-end
FPS and battery testing remain separate. Installer execution and repartitioning
were not repeated for this desktop revision; the independent target archive was
rebuilt and checked.
