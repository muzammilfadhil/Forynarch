# Build and verify

Edit source on Windows. Build with Archiso inside the Arch builder VM on a
Linux-native filesystem. Never run `mkarchiso` from PowerShell or build on the
Windows shared folder. See [automation](../automation.md) and
[VirtualBox builder setup](../virtualbox-builder.md) for approved workflows.

The builder needs librsvg to render the tiny boot PNGs from SVG sources.
Plymouth belongs to the target runtime; librsvg is not added to the core
manifest just for rendering those build assets. Git, Node.js, npm, pip, IDEs
and other developer selections remain opt-in during installation.

Run source checks in the Arch checkout:

```sh
python -m unittest discover -s tests -p 'test_*.py' -v
python scripts/hotkeys.py --check
bash -n scripts/configure-login.sh scripts/configure-boot.sh scripts/integrate-desktop.sh
shellcheck scripts/configure-login.sh scripts/configure-boot.sh scripts/integrate-desktop.sh
git diff --check
```

Windows can run pure Python tests. Native Bash, Qt/Quickshell, Hyprland, PAM,
Plymouth and partition-execution tests require an Arch VM or real hardware.
Passing Python tests alone does not validate the desktop or installer.

Before publishing an ISO, boot that exact artifact in UEFI, verify its checksum,
check Welcome and both buttons, test logout/login, inspect compositor/QML errors,
and test pack review/import/toggle/layout/export/remove. Boot screenshots must
show the animation; a black screen with quiet kernel messages is not a pass.

For the installed-core memory gate, close applications, wait five minutes and
sample `MemTotal - MemAvailable` from `/proc/meminfo` in bytes. Report swap
separately. The ceiling is **3,000,000,000 bytes**, decimal. Do not substitute a
Live snapshot, the builder's peak RAM, raw cache totals or a browser session.
Test custom widgets separately and keep unmeasured additions disabled by default.

Physical GPU handoff, mixed-scale monitors, Wi-Fi/Bluetooth hardware, suspend,
battery life, BIOS graphics and low-end FPS need real-machine testing. Disposable
QA VM disks must be identified by UUID/serial; host disks are never test targets.
