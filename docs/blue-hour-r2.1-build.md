# Blue Hour R2.1: consistent native window controls

15 October 2026. Preferred local artifact:
`out/iso/forynarch-2026.10.15-blue-hour-r2.1.iso`, **3,921,051,648 bytes**.
SHA-256:

```text
3feaa402203a0eda4db6666955e69ce916d3c04a64364025df923c54e9465383
```

Builder and Windows hashes match. Cold boot of this exact image passed in the
fresh UEFI QA VM. The unmodified profile reported the left-side GSettings
default, enabled File Manager CSD and native border resizing, and no Hyprland
configuration errors. Real Thunar opened floating at 922×576, position 179×144
on a 1280×800 display. Both packaged helpers matched source hashes. Native
Settings displayed the mode and size controls. Evidence:
`out/virtualbox/r2.1-file-manager-final.png`.

This supersedes R2 for new boots. It includes the same
[Hybrid/floating implementation](hybrid-floating-windows.md), plus the GSettings
default that keeps native GTK title controls on the left. The preceding R2
image exposed a conflict between GTK configuration and the schema default;
strict schema compilation and a native File Manager restart verified the fix.

The target rootfs and its checksums were regenerated. The corrected override
and compiled schemas were included in both target and the prepared Live root.
The installed Archiso 91 `_run_once` implementation was inspected before
invalidating only the SquashFS preparation and ISO build stamps. Those stages
were then rebuilt from the corrected filesystem. Package inventory, kernel,
boot entries and executable policy are unchanged from R2.

Source checks and native window behavior are recorded in the
[window review](hybrid-floating-windows.md). A fresh R2.1 installed-core RAM run
and full installation matrix have not been repeated; the measured installed
1.1956 GB peak belongs to R1. Hardware and application-specific decoration
behavior remain separate acceptance work.
