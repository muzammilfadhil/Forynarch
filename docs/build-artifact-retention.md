# Build artifact retention

Keep the newest ISO and a recent fallback. Keep any ISO referenced by a registered
VirtualBox machine or snapshot. Do not accumulate a full ISO for every UI edit.
Source, release verification notes and checksums belong in Git; generated ISO
images, VM disks, build caches and private SSH material do not.

On Windows, inspect the cleanup plan with:

```powershell
powershell -NoProfile -File scripts/cleanup-iso-artifacts.ps1
```

Use `-Apply` to remove the listed unused ISO files and their matching checksum
sidecars. The script keeps at least two recent releases, checks every ISO with
VirtualBox, refuses linked artifact directories and does not delete VM disks.
It writes a local inventory to `out/iso-cleanup-plan.json`. A referenced ISO is
retained even if the machine is currently off.

Builder cleanup requires a separate audit: retain the current target root,
archiso working tree, optional application payloads and package database needed
for the next build. Check for processes, mounts, loop devices and device-mapper
users before removing obsolete build directories. Deleting files inside a
dynamic VDI frees Linux space; reclaiming Windows space also requires guest TRIM
with supported discard, or zeroing free guest blocks and compacting the powered
off VDI. Always shut down the builder cleanly before offline compaction.
