# Blue Hour boot splash

Forynarch uses Plymouth for early graphical boot. The theme keeps the navy and
ice-blue palette, with a small F mark, five orbiting dots, a thin progress bar,
and a `0 / 100` counter explicitly labelled **estimated**. It uses Plymouth's
native boot-progress callback rather than a timer pretending to finish work.
The Live preparation service and login manager send short English status
messages. No video, desktop shell, web view or persistent helper is used.

Only the small dots animate. Text and the fill image update when their values
change. The four tiny PNG assets are rendered from original SVG sources on
the builder with librsvg; the renderer is not added to the target manifest.
Plymouth is a core runtime component and runs during boot, rather than staying
resident in the desktop.

Both the installed systemd initramfs and Live udev/Archiso initramfs include
the Plymouth hook after KMS. The theme, font and DRM/framebuffer renderers are
included by Arch's packaged hook. Initramfs compression uses zstd level 3.
Normal boot has `quiet splash loglevel=3`; failures can still surface, Esc
shows details, and installation creates a separate diagnostic boot entry.
The Live screen-reader entry keeps its verbose kernel parameters.

Builder dependency: librsvg (`rsvg-convert`). Target dependency: Plymouth
**26.134.222-3**, checked against the installed Arch package and its shipped
script example, initcpio hook and command help. Hook ordering also follows
the [Arch Plymouth documentation](https://wiki.archlinux.org/title/Plymouth).
No developer toolchain is selected for the installed core.

## Verification

Four policy tests cover both initramfs families, idempotence, rejection of
unreviewed hooks, preservation of `copytoram=n`, screen-reader parameters,
and the installer-restored initramfs template. The R4.2 script used unsupported
local-declaration syntax. Its replacement was included in both initramfs images
and the R4.3 ISO. A cold UEFI Live boot of that exact ISO displayed the Forynarch
mark, orbiting dots, progress counter and service description, then reached the
Live desktop. R4.3 SHA-256:
`f8a9fee05504ad2823ba5d0c01a43f7db8ffdffb3ae11da4ea3f0fd11f7c9ac2`.
The following revision uses an ASCII separator in the counter to avoid the
missing middle-dot glyph observed in the captured boot screen. The exact R4.4
ISO then showed the owner's four-point spark, moving dots, counter and service
description during cold UEFI boot. The desktop check confirmed Plymouth exited.
See the [R4.4 build record](blue-hour-r44-review.md). Installed boot animation and
Esc/details still need their own executed checks.

Hardware GPU handoff, BIOS graphics, encrypted-disk prompts and low-end boot
timings require additional hardware tests. The theme implements password and
question callbacks; encrypted installation is not added by this change.
