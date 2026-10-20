# Particle Circle GRUB menu

Forynarch uses the pinned **window** variant of
[Particle Circle](https://github.com/yeyushengfan258/Particle-circle-grub-theme)
by yeyushengfan258. Its navy/blue background and selection artwork appear before
the kernel starts. GRUB menu selection is followed by the existing animated
Forynarch Plymouth splash; the particles in the GRUB background are a static
image, not a running desktop shader.

The build stages the theme into the Live ISO and target root. Archiso's reviewed
`uefi.grub` mode replaces `uefi.systemd-boot`; the Live BIOS Syslinux path remains
available. Installation still requires UEFI, the storage review and affirmative
disk confirmation. The dedicated-disk installer installs GRUB fallback files
without changing firmware NVRAM entries. This change does not rewrite the boot
loader on a computer where Forynarch is already installed.

The installed system includes a diagnostic entry without quiet/splash options.
The Live screen-reader entry stays verbose. External operating-system probing
is off by default. Secure Boot provisioning, existing shared-ESP migration and
automatic alongside installation are not added by a theme change.

Runtime theme: `/usr/share/grub/themes/forynarch-particle/`.
Defaults: `/etc/default/grub`. After editing an installed system's GRUB settings,
its administrator regenerates `/boot/grub/grub.cfg` with `grub-mkconfig`.
These operations require administrator authentication; the source-staging helper
never invokes `grub-install` on the workstation or builder's own boot disk.

Graphics tries 1920×1080, 1600×900, 1366×768, 1280×800, 1024×768 and firmware auto
mode. GRUB has a console fallback if graphical terminal setup fails. Theme/font
memory is a boot-time allocation, with no additional desktop daemon.

Original files and changes are documented in
[UPSTREAM.md](../assets/grub/particle-circle-source/UPSTREAM.md). The GPL license
and font source are retained. The full desktop and installer verification is
recorded in the release review; source tests alone do not prove firmware boot.
