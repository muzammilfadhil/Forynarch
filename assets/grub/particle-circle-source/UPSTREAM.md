# Particle Circle boot menu

Source: [yeyushengfan258/Particle-circle-grub-theme](https://github.com/yeyushengfan258/Particle-circle-grub-theme),
revision `f27991237562f93aacc3f333be4284430889f5bb`, window/1080p variant.
The retained [GPL-3.0 license](../../../licenses/Particle-circle-GPL-3.0.txt)
applies to these upstream assets. `upstream.json` records original paths,
byte counts and SHA-256 checksums.

Forynarch retains the background, selection images and selected icons, uses its
own OS icon, changes the terminal font to the bundled Unifont, and scales the
instruction overlay to the current video size. Theme colors and the original
composition are preserved. GRUB entries, fallback graphics modes, timeout and
Plymouth handoff are configured separately by Forynarch.

The upstream `common/unifont.otf` is included as source for its generated PF2
font; `grub-mkfont -s 16 -o unifont-16.pf2 unifont.otf` regenerates it on a GRUB
builder. The OTF source is retained in this source directory, outside the runtime
theme payload. No upstream installer or generation script is executed.

## Font license

The bundled Unifont OTF metadata identifies a dual license: SIL OFL 1.1, or GPL-2.0-or-later with the GNU Font Embedding Exception. Forynarch uses the OFL option for the font, separately from the theme GPL-3.0 license. The copyright and OFL text are retained in `licenses/Unifont-OFL-1.1.txt` and staged alongside the GRUB font.
