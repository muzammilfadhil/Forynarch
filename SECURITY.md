# Security

Do not report credentials, BitLocker recovery keys, private keys or personal
disk contents in public issues. Revoke or rotate an exposed credential first.
Use the repository's private vulnerability reporting feature if enabled; until
it is available, do not attach a sensitive reproduction to a public issue.

Include the affected release, reproduction using disposable fixtures, expected
behavior and a redacted log. Installer, privilege, storage and existing-OS VM
issues should identify which safety boundary was crossed. Do not include a real
user's disk image. There is no security support SLA or hardware certification.

Before publishing a source snapshot, scan both the snapshot and any history
that will be pushed. `.gitignore` does not remove already committed secrets.
The publishing guide records the checks and the limits of this preparation.
