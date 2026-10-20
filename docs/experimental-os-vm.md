# Experimental existing-OS virtual machines

User request, 16 October 2026: optionally run an existing EFI operating system,
including a dual-boot Windows installation, inside QEMU while Forynarch remains
running. This extends the earlier optional virtualization scope. It does not
turn native EFI boot switching into simultaneous native execution.

## Contract

- Off by default, optional during installation and available in Settings.
- QEMU/OVMF/TPM tools are an unchecked software group, never core dependencies.
- No autostart, libvirt daemon, disk mapping or VM process while disabled.
- Enabling support does not open or write an existing operating-system volume.
- Launch requires a fresh reviewed plan and system authentication. Direct
  writes require a separate affirmative confirmation on every launch.
- Development tests use disposable file-backed block devices only. No personal
  Windows disk is an implementation/test target.

## Disk isolation

Whole-disk passthrough of a drive containing the running host is forbidden.
For same-SSD dual boot, build a private GPT view with the source disk GUID and
selected OS partition GUID/start/length preserved. Map only the selected OS
partition into that view. Unselected regions, including Forynarch, produce I/O
errors rather than exposing host data. Keep primary/backup GPT and a private
EFI filesystem in managed files. Append the virtual EFI partition after the
source disk's end; never rewrite the host GPT or shared EFI partition.

Use kernel device-mapper linear extents to retain exclusive claims on selected
partitions. Reject mounted volumes, swap, holders, host root/boot/home ancestry,
unsupported layouts, changed identity and ambiguous UUIDs. Managed mappings must
be ignored by UDisks. Revalidate at launch; a stale review is not authorization
for a different volume.

EFI files are copied into a private FAT image. The selected EFI executable also
becomes the guest's fallback boot entry. OVMF variables and an optional virtual
TPM belong to the VM. Host firmware boot order and Secure Boot settings are not
changed. EFI changes made by the guest remain private.

## Modes

See the [profile and BitLocker guide](wiki/existing-os-and-bitlocker.md) for the
Settings workflow. Guest network and audio are independently configurable per
profile and included in the reviewed launch identity. UEFI and software TPM 2.0
state persist privately per profile; the physical host TPM is never passed in.

**Preview:** source mapping is read-only, writes go to a temporary QCOW2 overlay
and are discarded after shutdown. No commit/merge command is exposed. Recreate
the overlay each run, so a subsequent native OS boot cannot invalidate a saved
overlay's backing data.

**Direct:** writes reach the selected existing OS partition. Initially restrict
this to clean, unencrypted NTFS and reject hibernation, Fast Startup, dirty
filesystems, unknown probe results and in-use devices. Never remove hibernation
files, force-mount, format, resize or repair the source. BitLocker cannot reuse
the hardware TPM inside a VM; encrypted direct writes remain unavailable.
An encrypted preview needs an explicit recovery-key acknowledgement and must
not collect or store that key in Forynarch.

Native OS storage drivers, activation, BitLocker, hardware-bound software and
major updates may behave differently under virtual hardware. Perform firmware,
partition and major Windows updates after native boot. Do not enable encryption
or repartition the passthrough volume inside the experimental VM.

## Process boundary and lifecycle

A narrow polkit helper validates selected identities and creates managed
resources. QEMU and swtpm run as the requesting user, never root. QEMU receives
opened mapped-device descriptors, not access to arbitrary host block devices.
Use on-demand systemd supervision, private QMP sockets, user-mode networking,
no host-folder export and no USB/GPU passthrough. Clean up mappings, loop devices
and preview files on exit. Reject disabling the feature while a VM is active;
offer guest shutdown first. Closing Settings must not kill a running VM.

Only fixed support packages can be installed. Settings labels the operation as
installing support and updating the system; no partial Arch upgrade is used.
Installed support packages do not imply an enabled VM or background service.

## Verification gates

1. Pure tests: profile validation, identity/mount/holder rejection, GPT CRC and
   partition bounds, masked gaps, resource limits, review digest and fixed QEMU
   arguments; developer groups remain opt-in.
2. Disposable native block fixtures: source partition byte hashes before/after
   preview; private GPT/EFI isolation; exclusive claim prevents host mounts;
   shutdown/crash cleanup; direct writes affect only the selected fixture extent.
3. QEMU/OVMF fixture boot: validate actual installed QEMU syntax and UEFI load
   without requiring a licensed Windows image; test GTK UI in the Live desktop.
4. Hardware acceptance remains separate: genuine Windows boot on SATA/NVMe,
   Windows shutdown/reboot, native boot afterwards, BitLocker recovery, multiple
   disks, 4Kn media and resource/battery measurements. A fixture boot does not
   prove an existing Windows installation boots successfully.

The idle core RAM gate applies with VMs stopped. Active VMs have separate guest
RAM allocations and are not included in a claim about idle desktop memory.

## Primary references

- [QEMU invocation and inherited file descriptors](https://www.qemu.org/docs/master/system/invocation.html)
- [QEMU disk image utility](https://www.qemu.org/docs/master/tools/qemu-img.html)
- [Kernel device-mapper linear targets](https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/linear.html)
- [NTFS mountability probe and exit codes](https://man.archlinux.org/man/ntfs-3g.probe.8.en)
- [Arch QEMU packaging](https://archlinux.org/packages/extra/x86_64/qemu/)
