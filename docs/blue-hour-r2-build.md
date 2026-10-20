# Blue Hour R2: hybrid and floating windows

Use [R2.1](blue-hour-r2.1-build.md) for new boots; it includes the final
schema-default correction for left-side GTK window controls.

15 October 2026. Local artifact:
`out/iso/forynarch-2026.10.15-blue-hour-r2.iso`, **3,921,051,648 bytes**.
SHA-256 verified on the Arch builder and independently on Windows:

```text
6c1ff36bf53abbacc48eff624a5104899bf194dd256e098e772228b95f48d470
```

The installed package inventory is unchanged from R1. R2 refreshes the target
payload, profile source integration and checksums, then uses a fresh Archiso
work directory. It adds Hybrid utility rules, adjustable initial floating sizes,
explicit active-window fit, edge/mouse resizing, native File Manager controls
and the corresponding Settings UI. See the
[implementation and verification report](hybrid-floating-windows.md).

The running installed QA VM received the same source changes, including the
updated Hyprland module list, without repartitioning or replacing its rootfs.
Its workspace defaults apply to new windows; open windows were preserved.
The application integration uses native GTK/Thunar facilities and existing
Hyprland rules rather than a new background service or compositor plugin.

Cold boot passed in a newly created UEFI VM with 3 GiB RAM and no virtual hard
disk. The unmodified image reached the glass desktop. Native border resizing
was enabled, `hyprctl configerrors` was empty, and File Manager CSD was enabled
in the fresh profile. Selecting Hybrid opened real Thunar floating at 922×576,
position 179×144 on a 1280×800 display. The Desktop settings showed all five
modes, three size presets, the explicit resize action and preserved-window
option. Packaged helper hashes matched the reviewed source. Evidence images:
`out/virtualbox/r2-settings-final.png` and `r2-file-manager-controls.png`.

The R1 full offline installation and five-minute installed-memory result remain
R1 evidence. A clean R2 installation matrix and fresh installed-core memory run
have not been repeated. Physical monitors, application-specific minimize
behavior and real-hardware pointer interaction remain acceptance work.
