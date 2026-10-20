# Boot, Welcome and login

Normal boot uses a navy Plymouth splash with a small animation, an estimated
`0 / 100` indicator and short English status messages. Progress reflects the
boot engine's estimate, not a fixed count of system services. **Esc** exposes
boot details. Installed systems also have a **Forynarch (diagnostic boot)** entry
without quiet/splash parameters. The Live accessibility entry stays verbose.

The Live ISO autologins once through SDDM, then opens Welcome:

- **Try Forynarch** dismisses Welcome and leaves the desktop available.
- **Install Forynarch** opens the standalone guided setup. It does not immediately
  format a disk or start installation.

Storage changes require reviewing a valid plan and affirmative confirmation.
The current installer supports dedicated-disk installation. Do not assume
automatic dual boot, shrinking existing partitions or a complete manual
partitioning installer is already implemented. The partition manager is a
separate advanced tool.

Logout ends the graphical user session, closes its applications, and returns
to the Kath SDDM greeter. Live autologin does not repeat on logout. Sign in starts
a new desktop session. Passwordless accounts show Sign in without asking for a
password; accounts with passwords still authenticate normally. Installed systems
do not inherit Live autologin or Live application-install authorization.

Use **Ctrl + Alt + F2** for a recovery terminal. It does not automatically launch
another compositor. [Implementation and checks](../live-welcome-login-review.md)
and [boot theme details](../graphical-boot.md) record validation limits.
The [R4.4 review](../blue-hour-r44-review.md) records the latest exact-ISO checks.

## Login background customization

The public image uses original Forynarch navy artwork with the adapted Astronaut theme. The video-capable theme code remains included. For a video you have permission to use, copy it locally into `/usr/share/sddm/themes/forynarch-kath/Backgrounds/` and set `Background` in `Themes/hyprland_kath.conf` to its relative filename. Keep a still image in `BackgroundPlaceholder` for loading/error fallback. This is an administrator change; do not add private or unlicensed media to a public source release. The ignored local Kath assets are not deleted by public-source export.
