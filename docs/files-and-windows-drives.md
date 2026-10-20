# Blue Hour files and Windows drive access

## Intent and affected source

Give the lightweight file manager a consistent navy interface and make Windows
data volumes understandable through familiar C:/D: aliases. Keep developer
toolchains optional, avoid continuous drive polling, and never guess drive letters.

Source: GTK styling, original SVG folder icons, Thunar defaults/actions,
GSettings vendor defaults, `DrivesPanel.qml`, on-demand `forynarch-drives` and
`forynarch-files` helpers, the JSON discovery filter, Windows metadata exporter,
UDisks mount defaults, core package input and target/Live installation wiring.

## Files interface

Thunar remains the native file manager. Blue Hour supplies a navy navigation
rail, readable toolbar, folder spacing, blue folder icons, breadcrumbs and a
wider sidebar. New users get icon view, symbolic navigation icons, folders
first, double-click activation, local-only thumbnails and a hidden menubar.
The toolbar menu and Alt key preserve access to menus. User choices can be
changed through Thunar preferences. Conventional home folders are initialized
only if there is no existing user-directory configuration.

Vendor GSettings defaults also set the icon theme, font and dark preference so
the GTK portal does not revert fresh applications to Adwaita icons. Explicit
user GSettings values take precedence. Existing Thunar processes keep their
loaded stylesheet until restarted. The Live preview installer backs up files
and merges custom actions without removing the user's unrelated actions.

Open **This Computer** through launcher search, its **Drives** quick action, or
the **Drives and storage** context action in Thunar. The panel lists available
data volumes, filesystem, capacity, mount location, access mode and protected
or encrypted status. Refresh scans on demand; closing the panel unloads it.
It uses the existing popover motion preferences and renderer.

## Windows interoperability

- NTFS reading uses `ntfs-3g`; exFAT uses the Linux filesystem driver, with
  `exfatprogs` available for maintenance. No formatting utility is invoked.
- NTFS UDisks defaults select the `ntfs` userspace driver and read-only access,
  including ordinary Thunar volume activation. **Mount read-only** requests
  `ro` explicitly, then checks the actual mount options before opening files.
- Already mounted read/write volumes are labeled **Read / write**, not falsely
  called read-only. The helper never remounts existing volumes automatically.
- EFI, Microsoft reserved/recovery, mounted root and boot partitions are
  protected from this panel's mount/unmount actions. BitLocker and LUKS are
  displayed as locked; this iteration does not unlock them or bypass encryption.
- No automount, repair, partition relabeling, forced unmount, hibernation-file
  removal, repartitioning or Windows filesystem write occurs during discovery.
- UDisks/Polkit retain their authorization checks. An unmount can refuse when
  files are busy. A successful mount/open of a mapped drive adds a URI-encoded
  sidebar bookmark with its familiar label, preserving existing bookmarks.

Windows letters are per-installation assignments. They are **not** NTFS labels
and cannot reliably be inferred from disk order. Mappings use GPT partition
UUIDs, with filesystem UUID fallback for a manually selected Linux alias.
Duplicate IDs or letters fail closed. The final device is checked against its
stable `/dev/disk/by-*` link before an action. Native Windows backslash paths
are not translated automatically.

On Windows, export the existing assignments with this read-only command:

```powershell
powershell -NoProfile -File scripts/export-windows-drives.ps1
```

This writes `out/windows-drives.json` without mounting, unlocking or changing
disks. It exports lettered GPT partitions; MBR/unsupported volumes require
manual aliases. The output contains machine-specific identifiers and must
remain outside Git. Copy it onto the Linux system, then run as the desktop user:

```bash
forynarch-drives import /path/to/windows-drives.json
```

Import changes local presentation only. It refuses to replace an existing map
without review. Alternatively, select a volume in This Computer, choose its
known Windows letter and click **Save**. Unmapped volumes have no guessed C:
assignment. A removed/replaced drive does not inherit another drive's letter.

A VM only sees its attached devices. Exporting the host mapping does not expose
the host's C:/D: files to VirtualBox. Access to a host Windows volume requires a
separately configured sharing or storage arrangement; none was created here.

## Verification and dependencies

Validated runtime: Thunar 4.20.10-1, GVfs 1.62.0-3, UDisks 2.11.2-1,
ntfs-3g 2026.9.28-1, exfatprogs 1.4.3-1, jq 1.8.2-1, GLib 2.90.1-1,
gsettings-desktop-schemas 51.0-1, Quickshell 0.3.2-1 and Hyprland 0.56.2-4.
Installed Thunar property/enum names were inspected before finalizing defaults.
GSettings overrides compile with `--strict`.

Core input now includes NTFS/exFAT maintenance support and jq. These are runtime
storage components; Git, Node, npm and developer groups remain opt-in. The
helpers use Bash/jq and existing components, with no Python target helper or
new custom background service. The Live configuration merge uses Live-only
Python; the existing documented Waybar runtime dependency exception is unchanged.

Executed checks and exact final results are recorded in `tests/latest-results.md`.
Storage tests use synthetic lsblk/findmnt data and disabled action stubs, never
real disk writes. They cover reordering, UUIDs, duplicate IDs/letters, malformed
imports, locked/protected volumes, access modes and URI-safe bookmarks.

The actual host exporter found four lettered GPT volumes; its map imported
successfully into the disposable Live user's configuration. The actual VM's
discovery returned no data filesystems, matching lsblk. Existing unformatted
virtual disks and Windows disks were not modified or mounted.

Final short RAM measurement with Thunar and production This Computer open:
peak **1,882,103,808 bytes (1.882 GB decimal)**, swap 0, collector exit 0,
six samples at nominal five-second intervals. This is whole-guest
`MemTotal - MemAvailable`, including retained apps and isolated preview
services. Raw log: `out/virtualbox/files-storage-memory.txt`. It remains below
the 3,000,000,000-byte limit in this check, without establishing installed-target
cold-boot idle acceptance.

Fresh native GTK rendering was checked in an isolated D-Bus session, preserving
existing user windows. Production This Computer discovery/empty state and an
isolated synthetic three-volume UI were checked separately. Synthetic UI
screenshots are labeled `files-drives-*-synthetic-qa.png`; their C:/D:/H: cards
are test fixtures, not evidence of mounted Windows files. All fixture backend
disk actions are disabled.

## Remaining gates

The existing ISO has not been rebuilt. Real NTFS/exFAT file reading, Polkit
prompts, hotplug, busy unmount, hibernated/unclean NTFS and BitLocker behavior
still need controlled disposable-volume and hardware tests. A full storage
release also needs trusted-drive policy, graphical map import/removal, stable
`/drives/C` aliases and optional shell `cd C:` translation from the vision.
Those features remain on the roadmap; this iteration implements discovery,
safe manual reading and familiar presentation.

Next smallest verification step: recover builder access, build the updated
profile, boot it fresh and validate storage against approved disposable test
volumes before touching any real Windows data.

References: [Thunar preferences](https://docs.xfce.org/xfce/thunar/preferences),
[Thunar styling](https://docs.xfce.org/xfce/thunar/hidden-settings),
[GSettings vendor overrides](https://docs.gtk.org/gio/class.Settings.html),
[UDisks mount options](https://storaged.org/udisks/docs/mount_options.html),
[UDisks actions](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html),
[Windows mount-manager identities](https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/supporting-mount-manager-requests-in-a-storage-class-driver),
[Get-Partition](https://learn.microsoft.com/en-us/powershell/module/storage/get-partition)
and [Get-Volume](https://learn.microsoft.com/en-us/powershell/module/storage/get-volume).
