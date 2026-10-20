# Logo and desktop identity

The Forynarch mark is the pale-blue **four-point spark** selected by the owner.
Its editable master is [`assets/branding/logo.svg`](../../assets/branding/logo.svg).
The original cropped launcher reference is preserved as
[`assets/branding/logo-reference.png`](../../assets/branding/logo-reference.png).
Its navy rounded square is the launcher button background, not part of the
transparent mark. The SVG reuses the existing launcher's vector geometry and now
has one source shared by boot, the desktop launcher, login and distribution icons.
The earlier F-shaped Plymouth placeholder has been retired.

Hyprland can also draw its own default logo/background and a random splash quote
before the wallpaper starts. Forynarch explicitly disables both in
[`config/hypr/identity.lua`](../../config/hypr/identity.lua). These options were
checked against the installed Hyprland 0.56.2 package and its
[official variables reference](https://wiki.hypr.land/Configuring/Basics/Variables/#misc).
The old whitespace-sensitive change to the packaged example did not reliably
disable the upstream logo.

The release metadata now identifies the system as Forynarch with `ID_LIKE=arch`
and `LOGO=forynarch`. Its `/etc/os-release` override preserves image metadata and
leaves the packaged `/usr/lib/os-release` untouched. A narrow pacman `NoUpgrade`
entry preserves the override when the base `filesystem` package is updated.
The underlying Arch packages and build provenance remain documented.

## Replace the logo in a build

1. Replace `assets/branding/logo.svg` with your own square SVG, retaining that
   filename. Keep its output `width="112" height="112"` for the boot mark;
   your artwork may use its own view box. The current view box is `0 0 24 24`.
   Leave breathing room around
   the mark so small launcher and login sizes remain legible.
2. Build on the Arch builder using the normal source pipeline. The branding step
   copies it to desktop/login and icon locations; the boot step renders its PNG
   and includes it in the initramfs.
3. Boot the resulting ISO and check the splash, login, launcher and distribution
   icons. Replacing a source file does not alter an ISO already built.

## Replace it on an installed system

Desktop and login read `/usr/share/forynarch/branding/logo.svg`. An administrator
can replace that file and log out/sign in to refresh cached images. Distribution
icon copies live under `/usr/share/icons/Forynarch`,
`/usr/share/icons/hicolor/scalable/apps/forynarch.svg` and
`/usr/share/pixmaps/forynarch.svg`; update these as well for a complete rebrand.

Plymouth reads `/usr/share/plymouth/themes/forynarch/mark.png`. Replacing it with
your own transparent 112 × 112 PNG requires rebuilding the initramfs with
`sudo mkinitcpio -P`. This is an explicit administrator operation, not a desktop
preference. The source rebuild is the recommended way to keep every copy aligned.

Application icons identify their own applications. Upstream credits, licenses
and technical package names remain available in the documentation and package
database; replacing visible OS branding does not remove their attribution.

Fastfetch uses /usr/share/forynarch/branding/terminal-logo.ansi, generated from the same SVG during the build using librsvg and Chafa. Rebuild after replacing the source logo to regenerate it. Neither tool runs when a terminal opens; Chafa is not a target dependency.
