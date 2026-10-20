# Existing Windows and BitLocker

This experimental feature is optional and disabled by default. Enable it in
**Settings → Virtual machines** or select its unchecked support group during OS
installation. Enabling support does not start a VM or open a disk.

## Configure a profile

Choose the operating-system partition, the EFI partition to copy privately and
the boot loader. Each profile has its own RAM, CPU, SATA/NVMe controller, network
and audio choices. Network uses user-mode NAT; turning it off removes the guest
network interface. Audio can be omitted independently. Neither choice shares
host folders. Changes invalidate the previous launch review.

Every profile retains private UEFI variables and software TPM 2.0 state. The
host's physical TPM is not passed through. Existing profiles retain their prior
network/audio behavior when opened after this update.

## Open a BitLocker-protected Windows volume

1. Boot Windows normally and obtain its matching **48-digit recovery password**.
   Keep it somewhere accessible without opening the encrypted Windows volume.
   Personal Microsoft accounts can use [Microsoft's recovery-key page](https://account.microsoft.com/devices/recoverykey).
   Organization-managed devices may require their IT administrator.
2. Disable Fast Startup and fully shut down Windows. A saved or hibernated
   Windows session must not be opened in a different hardware environment.
3. In Forynarch, select the BitLocker volume and its Windows EFI loader. The disk
   mode is restricted to **Preview**. Acknowledge that the recovery password is
   available, save the profile, and review the launch.
4. Authenticate the reviewed launch. If Windows displays BitLocker recovery,
   match the recovery-key ID and enter the password **inside the guest**.
   Forynarch has no recovery-password field, import mechanism or key store.
5. Shut down the guest when finished. Preview writes, including files saved
   inside Windows, are discarded. The source partition remains read-only.

Changing boot hardware, firmware or TPM measurements can trigger recovery.
Microsoft documents these triggers and the recovery-password mechanism in its
[BitLocker recovery overview](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/recovery-overview).
QEMU's [TPM documentation](https://www.qemu.org/docs/master/specs/tpm) describes
the software TPM used here. A software TPM does not contain the laptop TPM's
sealed key. Recovery may therefore be required on each preview launch, even
though the VM's own TPM state persists.

There is no supported way here to unlock an encrypted volume without a valid
recovery credential. Forynarch does not suspend BitLocker, decrypt the source,
change its protectors, clear a TPM or upload a recovery password. See
[Microsoft's recovery-key guide](https://support.microsoft.com/en-us/windows/security/encryption/find-your-bitlocker-recovery-key)
for locating an existing recovery password.

## Current limits

Encrypted volumes cannot use Direct mode. Preview is suitable for trying a
session; it is not persistent daily Windows storage. Persistent Windows work
needs a separately installed or cloned virtual disk, which this existing-volume
workflow does not create. Do not change encryption, partitioning or firmware
from inside this experimental VM.

Validation covers profile/device isolation and launch arguments. An actual
BitLocker Windows boot still needs a disposable Windows installation, its
recovery password and appropriate Windows licensing. Automated fixture success
does not certify compatibility with a particular laptop or Windows installation.
