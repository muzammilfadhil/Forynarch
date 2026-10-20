# Windows + VirtualBox builder

The agent can control an existing VirtualBox installation using VBoxManage. No Archiso build runs directly in PowerShell. The builder runs inside an Arch VM on ext4.

## Source automation

```powershell
powershell -NoProfile -File scripts/virtualbox-builder.ps1 -Action Plan
powershell -NoProfile -File scripts/virtualbox-builder.ps1 -Action Prepare
powershell -NoProfile -File scripts/virtualbox-builder.ps1 -Action VerifySignature
powershell -NoProfile -File scripts/virtualbox-builder.ps1 -Action Start
powershell -NoProfile -File scripts/virtualbox-builder.ps1 -Action Status
```

Prepare downloads current media from an official Arch mirror, verifies the SHA-256 published over official HTTPS and creates **a new VM only**. Existing VMs/disks are refused. VerifySignature uses an isolated public GPG keyring and the Arch-documented WKD signing identity. Start boots the official Live ISO headlessly without installing the OS. Open VirtualBox, select Forynarch-Builder and choose Show to view its console.

Defaults: Forynarch-Builder, 8 GiB RAM, 4 CPUs, UEFI, 80 GiB dynamic VDI and NAT. No physical/raw disk, shared folder or bridged interface is attached. ISO, VDI, screenshots, public keyring and runtime state are generated under out/virtualbox and ignored by Git.

## Provisioning approval

The separate bootstrap-virtualbox-arch.sh provisions only a **blank 80 GiB VirtualBox disk** with no partitions, mounts or holders. It refuses physical/non-VirtualBox hardware, a different disk size, multiple disks or preexisting signatures. Before it runs, approve these exact operations:

- Partition and format the new VM disk as GPT, FAT32 EFI and ext4 root.
- Install current stable Arch and builder tools (Python/Lua, archiso, test/VM tools; not a Forynarch end-user target).
- Create builder with SSH-key-only remote access and passwordless sudo inside this isolated VM.
- Write the new VM disk's EFI fallback files; boot/reboot the VM and configure localhost-only SSH access.
- Transfer project source onto ext4 and run the approved target/live build pipeline there.

The bootstrap script requires all three approval flags plus a public-key file. A host private SSH key, when generated, stays in ignored runtime storage and is never served/copied into the VM or committed. No passwords are printed or passed as process arguments. Approval for the builder does not approve erasing any real disk or installing a Forynarch target onto Windows storage.

## Executed preparation evidence — 14 October 2026

VirtualBox 7.2.20 was detected. No existing VM was registered. The preparation helper created Forynarch-Builder with the above resources and one new VDI. Arch 2026.10.01 ISO (1,640,497,152 bytes) passed official SHA-256 and GPG verification via WKD. The VM booted to the Live root console showing kernel 7.2.7-arch1-1. The attached storage was inspected: one generated VDI and the verified ISO, with no host disk attachment.

Arch installation, disk formatting, builder account/sudo/package setup and the actual ISO pipeline have **not** run. These remain behind the explicit approval gate from AGENTS.md.

Follow-up after the user approved execution: Arch builder installation completed on the new VDI and booted kernel 7.2.9-arch1-1 from ext4. SSH-key login and passwordless sudo were verified; source was transferred without caches/keys. A boot-readiness guard replaced fixed timing, and the Windows OpenSSH keyscan incompatibility was handled using the installed Git keyscan plus per-connection Curve25519 negotiation and strict host-key pinning.

The first native pipeline passed 42 tests and shellcheck, then stopped on the documented [Waybar runtime dependency](runtime-dependencies.md). The optional developer group remained unselected. The reviewed continuation uses --allow-core-dependency python; the wrapper exposes -AllowReviewedPythonRuntime rather than enabling it by default. Runtime exception metadata is included in the bundle and installer review.

References: [official Arch download/verification](https://archlinux.org/download/). VirtualBox command syntax was checked against the installed VBoxManage 7.2.20 help, including createvm, modifyvm and controlvm.
