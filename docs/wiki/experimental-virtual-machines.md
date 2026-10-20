# Existing operating systems in a virtual machine

This experimental feature opens an existing EFI operating system in a QEMU
window while Forynarch continues running. It is disabled by default. Installing
its optional software group does not enable or start a VM.

During installation, select **Existing OS virtual machines (experimental)** only
if you want the additional virtualization packages. On an installed system,
open **Settings → Virtual Machines**, enable the feature, and install support if
needed. Support installation requests administrator authentication and performs
a full Arch system update; a restart may be needed afterwards.

Create a profile, select the existing OS partition and its EFI partition, then
find and select its EFI executable. Windows normally uses
`EFI/Microsoft/Boot/bootmgfw.efi`. Review the detected disk identity and capacity
carefully. Shut the other OS down completely before launching it here. Windows
Fast Startup or hibernation can prevent access; this feature never removes
hibernation data or repairs the source filesystem.

**Preview** is the default. Changes go into a temporary overlay and are discarded
when the VM stops. There is no merge operation. **Direct** writes to the selected
OS partition and requires an additional confirmation at every launch. Keep a
verified backup before using Direct. Direct is currently restricted to clean,
unencrypted NTFS volumes containing a Windows installation.

Forynarch creates private EFI and firmware files. Other partitions on the disk
are hidden from the guest. Whole-host-disk passthrough, automatic startup, GPU
passthrough and automatic shared folders are not provided. Encrypted Windows
volumes are Preview-only and may request their BitLocker recovery key inside
the guest. Forynarch does not collect or bypass that key.

Shut down from inside the guest, or use **Request shutdown**. Closing Settings
does not stop a running guest. Force stop can lose unsaved guest data; Preview
uses a separate discard confirmation. Remove a stopped profile to delete only
its private VM files. Disabling the feature leaves installed support packages
available but starts no service or VM.

Hardware virtualization through KVM is required. Guest RAM is additional to
desktop RAM; selecting 4 GiB for Windows does not fit within the desktop's idle
3 GB budget. This feature has passed disposable disk and EFI boot tests, but
existing Windows installations, activation, device drivers, BitLocker, native
boot afterwards and 4Kn disks still require hardware acceptance testing.

For recovery after manually deleting configuration, the per-user command
`forynarch-vm status` lists managed VM identities. Send JSON containing an `id`
to `forynarch-vm shutdown` or `forynarch-vm recover`. Recovery releases only
inactive managed resources and requires system authentication.

See [the implementation contract](../experimental-os-vm.md) and
[verification report](../experimental-os-vm-review.md).
