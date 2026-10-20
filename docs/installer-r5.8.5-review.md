# Installer R5.8.5: Flatpak extra-data sandbox

The supplied installation log stops while installing the selected VS Code
Flatpak. Repository packages, Mudil Music and account creation had already run;
this is a failure after disk changes, before bootloader installation.

The previous runner launched Flatpak inside `arch-chroot`. Linux rejects creation
of unprivileged user namespaces from an ordinary chroot. VS Code's `apply_extra`
step invokes bubblewrap and therefore failed with a namespace permission error.
The earlier firmware warnings are not the cause of this failure.

## Change

`scripts/install-target.sh` now runs selected Flatpaks in a temporary
`systemd-nspawn` mount environment. Its trusted setup mounts a private procfs,
then drops to the reviewed user before running the normal user Flatpak install.
The private procfs also permits nested bubblewrap to mount its own procfs.
No global namespace sysctl changes or Flatpak sandbox overrides are applied.
No new service is enabled or package added. Empty Flatpak selections skip this
runner. Developer applications remain opt-in.

Before any disk writes, selected Flatpaks require the Live namespace tools and
a successful unprivileged namespace probe. Permanent installation errors stop
after one attempt; only recognized transient network errors retry once.

Runtime dependencies checked on the frozen build: systemd 262-1 (which provides
`systemd-nspawn`), util-linux 2.42.4 and bubblewrap 0.13.1. The runner uses
`--settings=no`, no registration, no new service unit, no private user remapping,
and no-new-privileges. Only its trusted setup retains mount capability; the app
runs with zero effective capabilities.

## Focused verification

- Bash syntax and ShellCheck: passed.
- Existing retry test: passed, covering transient recovery, exhausted network
  retries, permission denial and the reported namespace error.
- Guarded disposable overlay on the builder: the previous chroot runner failed
  with the same bubblewrap namespace message as the supplied log. The new runner
  exited 0 while executing real bubblewrap with user, PID, IPC, UTS and network
  namespaces, a proc mount and `--disable-userns` inside the sandbox. The app ran
  as UID 65534, with zero effective capabilities and no-new-privileges enabled.
- Preflight namespace probe: exit 0. Host namespace sysctl stayed unchanged.

The sandbox probe substitutes only the Flatpak CLI with a small fixture that
executes actual bubblewrap. It does **not** claim a complete VS Code download or
installation. No personal disk, EFI entry or user account was modified by it.

The ISO updates the Live installer only. The installed rootfs, package selection
and prior desktop features remain from R5.8.4. Full desktop QC, a full selected
Flatpak transaction, physical installation and an installed memory benchmark
were not repeated. The next acceptance step is the reviewed installation with
the same selected applications on a disposable target, followed by boot.

## Recovery

Use the new ISO and review the intended Linux root and EFI partitions before
retrying. The failed attempt is incomplete and must not be treated as bootable.
Selecting prepared partitions formats the selected Linux root again; confirm
that target explicitly and keep other partitions preserved. Do not assume that
the old error happened before disk writes.

References: [Linux namespace checks](https://github.com/torvalds/linux/blob/master/kernel/user_namespace.c),
[Flatpak namespace requirements](https://github.com/flatpak/flatpak/wiki/User-namespace-requirements),
[systemd-nspawn](https://man.archlinux.org/man/systemd-nspawn.1.en),
[bubblewrap](https://man.archlinux.org/man/bwrap.1.en).

## Artifact

`forynarch-2026.10.18-blue-hour-r5.8.5.iso` (3839197184 bytes).

SHA-256: `e33c1a181c6d4b26d88dbb0e9a4a15a9aa255eb392e3489e2e0a8c1a9d9b57bb`.

The builder and Windows checksums match. Fourteen Live source files and
eleven retained target-bundle source files match their expected hashes.
All four Live namespace executables are present in the squashfs. The core
remains 573 packages without unselected developer packages.
