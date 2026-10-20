# Blue Hour R1 build

Built on 15 October 2026 with Archiso 91 in the Arch builder, using Linux-native
ext4 storage. No `mkarchiso` command ran in PowerShell.

Local artifact: `out/iso/forynarch-2026.10.15-blue-hour-r1.iso`.
Size: **3,921,051,648 bytes**.
SHA-256, verified independently on builder and Windows:

```text
c3186f5fc2621ff8896d3b9c1d9d99564b12a632fe03e817bd5a3a563450460a
```

R1 refreshes the already built target/profile source integration and reconstructs
the target payload and checksums, then runs `mkarchiso` with a fresh work directory.
The target package inventory is unchanged from the verified base candidate.
It includes the final popup focus, mode-lock and normal-session logout fixes,
the passwordless greeter navigation fix and the latest emoji/GIPHY interface.
Source-only documentation updates after packaging do not alter the artifact.

The normal local-media boot entries use `copytoram=n`; explicitly selected
copy-to-RAM entries remain available. Ventoy's optional memdisk mode and the
Live writable overlay are separate from installed-system memory measurements.

Cold boot in a fresh UEFI VirtualBox VM reached the actual glass Live desktop.
NetworkManager and Live preparation were active; SSH, Avahi, networkd and iwd
were inactive. All inspected local helpers and the root installer executor were
executable. Firefox is available in Live. The GnuPG SSH-agent emulation socket
is cryptographic-agent infrastructure, not an SSH login server.

The R1 image also completed a real offline graphical installation to a second
verified blank 48 GB virtual disk, with no optional groups and passwordless
sign-in. The installed EFI system booted from that disk after the ISO was
ejected. Kath hid the password field, and sign-in reached the glass desktop.
`en_US.UTF-8` was generated correctly without a manual repair. Firefox, Git,
Node.js, npm and pip were absent; the documented Python runtime dependency
remained. NetworkManager was active; remote login/advertising services were off.

Final installed R1 idle measurement, after five minutes with four default
widgets, glass and motion, peaked at **1,195,581,440 bytes** over six samples.
Swap used was **0 bytes**. The VM had two CPUs and 4 GiB RAM. This passes the
3,000,000,000-byte installed-core memory gate; it is not a Live measurement.

This is an experimental installation image. The confirmed whole-disk installer
must be used only after reviewing the chosen disk. Unsupported alongside/manual
layouts, encryption and unvalidated drivers remain blocked. See the
[desktop review](production-desktop-review-2026-10-15.md) for exact test coverage
and memory measurements.
