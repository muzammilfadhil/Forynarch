# Latest stable Arch baseline

Checked 14 October 2026. User preference: latest Arch Linux.

The [official download page](https://archlinux.org/download/) lists installation media **2026.10.01**, with included kernel **7.2.7**. The [stable Hyprland package page](https://archlinux.org/packages/extra/x86_64/hyprland/) currently lists **0.56.2-4**. These are observations, not a frozen package snapshot or proof of installed versions. Arch is rolling: bootstrap from the latest official media and use the current stable repositories at build time.

Do not enable testing/AUR merely to get a newer version. Do not perform partial upgrades. A full update on the Arch builder requires explicit approval for package installation. Record actual installed versions and repository database timestamps using `scripts/record-build-environment.sh`; that script does not update databases or install packages.

The [Hyprland configuration index](https://wiki.hypr.land/configuring/) warns that its default documentation follows the latest Git commit. Select the matching installed version. The [core configuration page](https://wiki.hypr.land/configuring/core/) describes Lua; implementation still requires checking the release actually installed in the builder, as required by AGENTS.md. No Forynarch Lua configuration is shipped yet.

Prototype desktop references: [Foot](https://man.archlinux.org/man/foot.ini.5.en), [Fuzzel](https://man.archlinux.org/man/fuzzel.ini.5.en), [Mako](https://man.archlinux.org/man/mako.5.en), [Waybar](https://man.archlinux.org/man/waybar.5.en). The source files use restrained opaque navy surfaces and packaged fonts. Syntax/runtime validation against installed versions is outstanding.
The Foot prototype uses the current documented `colors-dark` section rather than the older `colors` section. Waybar's workspace module remains native per-output display; it does not implement the future monitor-local mapping controller.

## Builder handoff

1. Obtain latest official Arch media from the download page and verify signature/checksum. Do not commit it to source.
2. Use an isolated x86_64 Arch VM with native ext4/Btrfs/XFS or another accepted Linux-native filesystem. Do not use host disks for installation tests.
3. Copy/clone source into the VM. Obtain explicit approval before installing/updating builder packages, creating users, configuring sudo or changing disks/EFI.
4. Record installed versions and inspect shipped Hyprland examples. Validate proposed package names/dependency closure with existing package metadata; review runtime exceptions.
5. Run planner contract tests and `bash -n`/shellcheck. Prototype the session using matching configuration syntax, then test on suitable graphics hardware.
6. Run profile setup/build only in the authorized Arch environment. The helper still creates a releng starter image, not an integrated Forynarch installer.

Latest packages and reproducible builds need separate evidence: save actual versions and profile hashes for each build, then choose a dated repository snapshot/archive when a repeatable release candidate is needed. Recording a timestamp alone does not make a build reproducible.
