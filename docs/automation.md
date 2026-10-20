# Automated build and experimental installation

Status: implemented source with local contract/syntax checks; **not yet executed in Arch or validated on a disk**. This pipeline builds a basic Live desktop and a separate target for dedicated-disk CLI installation. It does not make every vision milestone complete.

## Entry points

| Script | Purpose | Approval boundary |
| --- | --- | --- |
| scripts/forynarch.ps1 | Windows plan/check or SSH into an existing Arch VM | Local checks install nothing; remote build needs approval switches and sudo in the VM |
| scripts/forynarch.sh | Builder plan/doctor/bootstrap/build | Separate approvals for host packages, target packages and image configuration |
| scripts/test-live-vm.sh | New disposable QEMU disk and isolated UEFI variables | Generated files under out/ only; no host block devices; guest QA is interactive |
| scripts/install-target.sh | Live command forynarch-install | Review by default; --execute plus typed disk-specific consent before target operations |
| scripts/automation_support.py | Archive/manifest/inventory/partition checks and installed-example adaptation | Builder/live tooling; never automatically added to target |

## Windows source check

```powershell
powershell -NoProfile -File scripts/forynarch.ps1 -Action Plan
powershell -NoProfile -File scripts/forynarch.ps1 -Action Check
```

Uses existing Python and Git Bash; does not install WSL/VM software or run mkarchiso. Prepare an Arch VM separately using [current-baseline.md](current-baseline.md). Builder account/sudo/disk setup requires explicit approval.

For an installed VirtualBox on Windows, [virtualbox-builder.md](virtualbox-builder.md) provides automatic creation, verified ISO download and Live boot. A prepared VM still requires approval before the separate builder bootstrap formats its new disk or installs packages/accounts.

## One-command Arch pipeline

Copy/clone source into an existing Arch x86_64 VM on a Linux-native filesystem. Inspect first:

```bash
bash scripts/forynarch.sh plan
bash scripts/forynarch.sh doctor
```

After approving the listed operations:

```bash
sudo bash scripts/forynarch.sh build \
  --approve-host-packages \
  --approve-target-packages \
  --approve-image-config
```

Host approval authorizes a full stable Arch update and builder/test tools, including builder-only Python. Target approval authorizes packages in an independent generated root directory, never a host disk. Image configuration authorizes desktop templates and offline NetworkManager enablement. The builder creates no accounts. Omit host approval when tools are already installed. Testing/AUR/custom builder repositories are rejected.

Stages: source tests and shellcheck; package-name validation; independent pacstrap target; explicit/full package inventories and leak audit; installed Hyprland version/example checks; desktop integration; separate filesystem/database payloads; fresh releng Live profile with installer; ISO/checksum/version evidence.

The Hyprland adapter currently supports the observed stable 0.56.2 release. A newer incompatible release stops for review and never silently downgrades. All optional groups remain off. An unavoidable Python dependency stops the core build unless separately reviewed and authorized with --allow-core-dependency python; it must remain a transitive runtime with recorded evidence. Git/Node/npm/IDE/container leaks remain failures.

Outputs use unique work/pipeline-* and out/build-* directories. Failed runs retain evidence; there is no recursive cleanup or reuse of unknown partial roots. Target archives exclude caches/runtime files and builder private pacman keys. Installation generates a fresh keyring.

Remote execution after copying source into the VM:

```powershell
powershell -NoProfile -File scripts/forynarch.ps1 -Action BuildRemote `
  -SshTarget YOUR_USER@YOUR_VM -RemotePath /home/YOUR_USER/Forynarch `
  -ApproveHostPackages -ApproveTargetPackages -ApproveImageConfig
```

Replace host/path; SSH/sudo handle passwords interactively. This does not provision the VM.

## Disposable VM test

Use the ISO path printed by the build:

```bash
bash scripts/test-live-vm.sh /absolute/path/to/forynarch.iso
```

Creates a fresh sparse 40 GiB disk, private firmware variables and user-mode networking. No host disk is attached. Identify the actual guest by-id link for serial FORYNARCH_QA inside the guest. VM boot alone does not prove GPU support or installer safety; each QA invocation starts a fresh disk.

## CLI installation

Supports **UEFI + GPT + ext4 on a dedicated disk**. There is no install-alongside mode: confirmed execution erases all Windows/data on that disk. Initial QA must use disposable guest disks. BIOS, encryption, shared partitions and Secure Boot remain pending.

Inspect and choose a stable whole-disk link yourself inside Live:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
ls -l /dev/disk/by-id/
read -r -p 'Reviewed whole-disk by-id path: ' REVIEWED_DISK_ID
forynarch-install --disk "$REVIEWED_DISK_ID" --username forynarch --timezone Asia/Jakarta
```

The installer validates bundle integrity/archive paths, rejects mounted/live/system/swap/holder devices, resolves optional operations from bundled database metadata, and displays existing partitions, new layout, account, software and EFI actions. No selections means no optional transaction and no core download requirement.

After reviewing, execute:

```bash
forynarch-install --disk "$REVIEWED_DISK_ID" \
  --username forynarch --timezone Asia/Jakarta --execute
```

It still requires typing ERASE ALL DATA ON followed by the exact reviewed by-id path. That approves all displayed formatting, target packages/filesystem, administrator/password/sudo setup and EFI fallback-file operations. Passwords are interactive, never command arguments/logs. Firmware NVRAM and reboot are not modified.

Optional groups use repeated --select arguments: --select git or --select nodejs-npm --select python. Downloads and signature checks complete before disk writes; the plan and disk identity are rechecked. The installer does not refresh databases or perform a partial upgrade. If snapshot packages disappeared from mirrors, it stops before partitioning; rebuild current media. --offline rejects optional selections because no offline add-on bundle exists.

After extraction it configures fstab, locale/timezone/hostname, a fresh keyring, an ordinary wheel user, initramfs and systemd-boot fallback files. It checks installed versions and explicit reasons against reviewed core + transaction. Normal user login on tty1 starts Hyprland; tty2 remains recovery. The updated Live profile prepares a separate non-wheel liveuser and starts the desktop through normal tty1 login. See [desktop preview](desktop-preview.md) and the executed QA record for current limits.

Checksums prove bundle integrity, not independent authenticity. Use a trusted build/verified ISO; signed releases remain a release gate. Errors after partitioning can leave a partial installation: inspect/recover rather than automatically erasing again.

## Required QA before real-disk use

Fresh disposable VM cases: review/cancel, zero, Git-only, JS-only, Python-only, combined, offline core, unavailable offline extras, network/signature failure, disk full and EFI failure. Compare disk snapshots for cancellation; verify inventories/login/network/audio/recovery after reboot. Real GPU/multi-monitor and laptop power testing are separate. Record executed evidence; generated code is not a passing test.

Calamares, hybrid workspace defaults/local shortcuts, MRU switcher, storage aliases/policies, dual-boot preservation, Windows application/VM integration and measured power profiles remain the roadmap. Their automation needs implementation and hardware evidence; pipeline reports them as pending.

Official references: [pacstrap](https://man.archlinux.org/man/pacstrap.8.en), [mkarchiso](https://man.archlinux.org/man/mkarchiso.1.en), [pacman](https://man.archlinux.org/man/pacman.8.en), [sfdisk](https://man.archlinux.org/man/sfdisk.8.en), [bootctl](https://man.archlinux.org/man/bootctl.1.en), [versioned Hyprland example](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua). Installed examples are checked at execution before adaptation.
