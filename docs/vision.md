# Forynarch

**An Arch-based Linux distribution designed for clarity, efficiency, and everyday freedom.**

**Project started:** October 12, 2026  
**Creator:** Muhammad Muzammil Fadhil  
**Status:** Early development / Concept and architecture planning  
**Base:** Arch Linux  
**Desktop compositor:** Hyprland

---

## 1. Start of the Journey

On October 12, 2026, I began planning Forynarch, a personal Arch Linux-based distribution intended to combine minimalism, performance, flexibility, and a refined desktop experience.

The project started from my frustrations with Windows, particularly excessive battery consumption, unnecessary background processes, and laptop temperatures that frequently become uncomfortable during everyday use.

I wanted an operating system that feels lightweight without sacrificing usability, customization, or visual quality.

Forynarch is intended to be more than a collection of themes and configurations. It should provide a cohesive desktop experience where window management, storage access, power efficiency, and daily workflows feel naturally connected.

**Core philosophy:**

- Minimal, but never incomplete.
- Elegant, but never unnecessarily decorative.
- Efficient, without sacrificing usability.
- Customizable, without requiring constant manual configuration.
- Linux-native, while making Windows interoperability as convenient as realistically possible.

The goal is not to recreate Windows, but to remove unnecessary friction from using Linux.

---

## 2. Intended Desktop Experience

Forynarch will use Arch Linux with Hyprland as its primary desktop environment foundation.

The desktop should feel refined, responsive, and consistent across different screen sizes and hardware configurations.

### Visual direction

- Dark-first interface with a distinctive navy identity.
- Refined typography, subtle rounded corners, and balanced spacing.
- Restrained animations with consistently smooth transitions.
- Minimal visual clutter and carefully selected UI components.
- Premium visual identity without excessive transparency, gradients, or unnecessary effects.
- Lightweight desktop components and reduced background resource consumption.
- Optional reduced-motion and low-power visual settings.

Forynarch should feel equally comfortable for programming, browsing, studying, file management, and general daily usage.

---

## 3. Hybrid Window Management

One of Forynarch's defining features will be its hybrid tiling and floating window management system.

Hyprland already provides foundational tiling and floating functionality. Forynarch will build a more intuitive interaction layer on top of it.

### Window behavior

Every window should support switching between:

**Tiling mode**
- Windows are automatically arranged by the compositor.
- Suitable for programming, multitasking, and structured workflows.
- Windows can be rearranged using keyboard shortcuts.

**Floating mode**
- Windows can be freely moved and resized.
- Users can drag windows using the mouse.
- Windows can overlap, similar to a conventional desktop.
- Window positions and dimensions may be remembered when appropriate.

### Workspace preferences

Each workspace should have an independent preferred window mode.

For example:

| Workspace | Purpose | Preferred mode |
|---|---|---|
| 1 | Programming | Tiling |
| 2 | Browser | Floating |
| 3 | Terminal | Tiling |
| 4 | Productivity | Mixed |
| 5 | General use | Floating |

The configured workspace mode should determine how newly opened windows behave by default.

Users should also be able to change the mode of an existing window without changing the entire workspace.

Switching workspace modes should optionally rearrange existing windows, with predictable behavior and minimal disruption.

### Workspace indicators

The workspace indicator in the top bar should provide subtle information about the current workspace mode.

Suggested indicators:

- `T` = Tiling
- `F` = Floating
- `M` = Mixed

The indicators should remain minimal, readable, and visually consistent with Forynarch's design language.

The current window's state should also be distinguishable when necessary.

---

## 4. Independent Multi-Monitor Workspaces

Forynarch should treat each connected display as an independent workspace environment.

Each monitor should have five primary workspaces by default.

**Example:**

| Display | Internal workspace IDs | Visible workspace keys |
|---|---|---|
| Monitor 1 | 1–5 | 1–5 |
| Monitor 2 | 6–10 | 1–5 |
| Monitor 3 | 11–15 | 1–5 |

Workspace shortcuts should operate relative to the currently focused monitor.

For example, pressing `Super + 2` should open the second workspace belonging to the active monitor, rather than always targeting global workspace 2.

Additional requirements:

- Each monitor has an independent workspace indicator.
- Each monitor remembers its active workspace.
- Users can move windows between monitors.
- Floating windows should retain sensible positions when changing displays.
- Monitor connection and disconnection should be handled automatically.
- Workspaces should be reassigned safely when a monitor is disconnected.
- Workspace configurations should support persistent monitor identities where possible.
- The mouse cursor should follow monitor focus when explicitly requested.

This behavior may require additional scripts or a lightweight Forynarch workspace manager rather than Hyprland configuration alone.

---

## 5. Keyboard and Mouse Interaction

User clarification, 15 October 2026: Super with an arrow changes window focus;
adding Shift swaps windows. The table below reflects this later instruction.

Forynarch should combine efficient Hyprland shortcuts with familiar Windows-like navigation.

| Shortcut | Intended action |
|---|---|
| `Alt + Tab` | Switch between recently used applications with a Windows-like switcher |
| `Alt + Shift + Tab` | Switch applications in reverse order |
| `Super + 1–5` | Change workspace on the focused monitor |
| `Super + Shift + 1–5` | Move the active window to a workspace on the focused monitor |
| `Super + Arrow` | Focus another window in the selected direction |
| `Super + Shift + Arrow` | Swap the active window with its neighbor in the selected direction |
| `Super + Space` | Open the main search and application launcher |
| `Super + Alt + Shift + Tab` | Focus another monitor and move the cursor to it |
| Configurable shortcut | Toggle the active window between floating and tiling |
| `Super + Mouse Drag` | Move floating windows |
| `Super + Right Mouse Drag` | Resize floating windows |

The `Alt + Tab` experience should prioritize recently used applications instead of simply cycling through windows in an arbitrary order.

Window previews and application icons are desirable, provided the selected switcher supports them reliably.

The main launcher should eventually support application searching, file searching, system commands, and quick actions.

All shortcuts should be configurable without editing numerous unrelated configuration files.

---

## 6. Smart Drive and Storage Management

Forynarch should make storage management easier for users coming from Windows.

Users should not need to manually identify partitions, edit `/etc/fstab`, or type complicated mount paths just to access a secondary disk.

### Automatic drive discovery

The system should detect supported storage devices, including:

- Internal SSDs and HDDs.
- NVMe devices.
- External USB drives.
- Additional partitions.
- Supported Windows NTFS partitions.
- Linux filesystem partitions.
- Encrypted volumes, when supported and properly unlocked.

Detected drives should appear automatically in the file manager.

### Familiar drive presentation

Forynarch should provide a simplified drive interface inspired by Windows.

Example:

```text
This Computer
├── System
├── Windows (C:)
├── Data (D:)
├── Projects (E:)
└── USB Drive (F:)
```

These names represent user-facing labels and aliases, not a replacement for the Linux filesystem hierarchy.

The actual mount locations can remain Linux-native.

A dedicated compatibility layer should expose convenient aliases:

```bash
cd /drives/C
cd /drives/D
cd /drives/E
```

An optional shell integration should support drive-style shortcuts:

```bash
cd C:
cd D:
cd E:
```

These shortcuts would be translated internally to valid Linux paths.

Native Windows backslash paths should not be assumed to work automatically in every Linux application.

Drive mappings must use stable identifiers such as filesystem UUIDs rather than relying only on device names.

### Smart auto-mounting

Forynarch should allow users to configure mounting preferences independently for each drive.

Supported policies:

1. Automatically mount trusted drives.
2. Ask for authorization when necessary.
3. Mount only when manually requested.

Trusted, unencrypted data drives should be accessible without repeated authentication when permitted by the configured security policy.

System partitions, encrypted drives, and sensitive storage must retain appropriate protection.

Users should be able to modify these preferences through a graphical settings interface.

### Safety requirements

- Never bypass filesystem encryption.
- Never silently format or alter existing partitions.
- Do not automatically mount EFI or recovery partitions for writing.
- Prevent unsafe write access to hibernated or otherwise inconsistent Windows filesystems.
- Provide safe eject and unmount functionality.
- Prefer read-only access when filesystem integrity is uncertain.
- Preserve compatibility with Linux permissions and security policies.

The goal is convenience without compromising data integrity or system security.

---

## 7. Windows and Linux Filesystem Interoperability

Forynarch should make it easy to exchange files between Linux and Windows installations.

### Filesystem strategy

For the operating system itself, prefer a Linux-native filesystem such as:

- Btrfs, potentially with snapshot support.
- ext4, as a straightforward and reliable alternative.

For shared data partitions, support:

- NTFS for compatibility with Windows.
- exFAT for portable shared storage.

A dedicated shared-data partition may be offered during installation.

Example disk layout:

```text
EFI System Partition
Windows System Partition (NTFS)
Forynarch Root Partition (Btrfs/ext4)
Shared Data Partition (NTFS/exFAT)
```

Forynarch must not promise that a Linux-native root filesystem will be directly readable by standard Windows installations.

Access through additional tools or WSL may be documented where supported.

The shared-data partition should provide the primary seamless file-exchange experience.

---

## 8. Windows Application Compatibility

A long-term goal is to make Forynarch highly compatible with common Windows applications without requiring users to leave their Linux desktop.

However, Forynarch should distinguish between running Windows applications and running the Windows operating system itself.

### Native-style Windows application support

Prioritize compatibility solutions such as:

- Wine for Windows application compatibility.
- Bottles for managing isolated Wine environments.
- Proton for supported Windows games.
- Desktop integration for compatible `.exe` applications.

Where possible, compatible applications should:

- Launch from the normal application menu.
- Open as regular Hyprland windows.
- Support floating and tiling.
- Appear in the application switcher.
- Access user-approved files and directories.
- Integrate with the notification and task management systems where supported.

Compatibility must be evaluated per application.

Forynarch should not claim universal compatibility with Windows software, especially applications dependent on specific drivers, kernel components, or unsupported Windows features.

### Optional Windows environment

For applications that cannot run through a compatibility layer, Forynarch may provide an optional Windows virtualization integration.

This could use KVM/QEMU and a suitable desktop integration layer.

The Windows environment may appear in a window or fullscreen, depending on the virtualization setup.

This capability must remain optional because running another operating system consumes additional memory, CPU resources, and storage.

---

## 9. Other Operating System Access and Boot Integration

Forynarch should detect existing supported operating systems and make switching between them convenient.

### Boot discovery

The system should identify valid boot entries, including:

- Forynarch.
- Windows Boot Manager.
- Other supported Linux installations.

A graphical interface should display available operating systems without requiring users to manually inspect EFI entries.

### Switch to another OS

Users should be able to select an operating system through the launcher or power menu.

Example:

```text
Power
├── Shut Down
├── Restart
├── Sleep
├── Hibernate
└── Switch Operating System
    ├── Windows
    └── Other Linux
```

Selecting another native operating system should offer a controlled reboot into its boot entry, when supported by the bootloader and firmware.

The system must save or close active work appropriately before rebooting.

### Simultaneous OS limitation

Booting a separate Windows installation directly through EFI while keeping the current Linux kernel running is not a supported native dual-boot mechanism.

Forynarch should not attempt to advertise simultaneous native Windows and Linux sessions without virtualization.

Instead, the intended user experience should combine:

1. Windows application compatibility layers for supported applications.
2. Optional virtualization for applications requiring a complete Windows environment.
3. Convenient native boot switching when the user needs full hardware-level Windows compatibility.

The objective is seamless interoperability, not an unrealistic replacement of firmware or operating system isolation.

---

## 10. Battery Life, Temperature, and Performance

Power efficiency is one of the primary reasons Forynarch exists.

The operating system should prioritize sensible resource management rather than merely appearing lightweight.

### Performance goals

- Reduce unnecessary background services.
- Minimize idle CPU and memory consumption.
- Avoid unnecessary visual effects.
- Use hardware acceleration where supported.
- Reduce excessive disk activity.
- Maintain responsive application launching.
- Provide sensible suspend and resume behavior.

### Power management

Forynarch should provide configurable profiles:

| Profile | Purpose |
|---|---|
| Eco | Prioritize battery life |
| Balanced | Everyday use |
| Performance | Prioritize responsiveness |

Potential technologies include TLP, tuned, or power-profiles-daemon, selected according to the target hardware and compatibility requirements.

Conflicting power management services must not be enabled simultaneously.

The system should support automatic profile changes based on AC or battery power.

### Thermal management

- Monitor supported CPU temperature sensors.
- Use appropriate CPU frequency and power policies.
- Avoid unnecessary high-performance states.
- Support hardware-specific thermal control where available.
- Prevent overheating-related performance problems where software control is possible.

Battery improvements must be measured against a controlled baseline.

Forynarch should never promise better battery life or lower temperatures on every device without testing.

---

## 11. Default Applications and System Components

The default installation should include a small but capable collection of applications.

### Proposed initial stack

| Component | Preferred starting point |
|---|---|
| Base distribution | Arch Linux |
| Desktop compositor | Hyprland |
| Status bar | Waybar |
| Terminal | Foot |
| Application launcher | Fuzzel |
| File manager | Thunar or equivalent |
| Network management | NetworkManager |
| Storage management | UDisks2 with a suitable automount integration |
| Authentication | Polkit agent |
| Notifications | Lightweight Wayland notification daemon |
| Audio | PipeWire and WirePlumber |
| Boot management | UEFI-compatible bootloader |
| ISO building | archiso |

Components should be chosen based on reliability, compatibility, resource usage, and maintainability.

The initial release should prioritize a functional desktop rather than a large collection of preinstalled applications.

---

## 12. Visual Identity

**Name:** Forynarch  
**Style:** Refined, modern, minimal, and distinctive  
**Primary identity:** Navy and soft blue with warm contrasting accents

### Color palette

| Color | Hex | Intended use |
|---|---|---|
| Deep Blue | `#425B9A` | Primary accent |
| Sky Blue | `#76C0EC` | Secondary accent |
| Warm Cream | `#FFF6DC` | Text or light surfaces |
| Soft Peach | `#F2B49B` | Highlights |
| Dark Navy | `#293B5F` | Dark surface or supporting color |

Forynarch should not look like a generic black desktop with neon accents.

The design should feel comfortable, expressive, and polished without becoming visually overwhelming.

### Remaining design decisions

- Typography and font weights.
- Logo and icon language.
- Wallpaper direction.
- Top bar composition.
- Window borders and radius.
- Animation timing.
- Notification appearance.
- Application launcher layout.
- Settings interface.
- System sound design.
- Optional light theme.

The final design must maintain good text contrast and accessibility.

---

## 13. Installation and Distribution Strategy

Forynarch should initially be developed as a reproducible Arch Linux configuration and package selection, then progressively become a bootable distribution image.

### Initial development principles

- Use reproducible configuration files and build scripts.
- Track changes through Git.
- Document dependencies.
- Test pinned, known-compatible package versions.
- Avoid unnecessary modifications to core Arch Linux components.
- Preserve a recovery path if graphical startup fails.
- Separate the live environment from the installation process.
- Do not claim the ISO contains a functional installer until installation has been implemented and tested.

### Installation goals

A future graphical installer should eventually support:

- Guided installation.
- Manual partitioning.
- Existing Windows installation detection.
- Safe dual-boot configuration.
- Optional shared-data partition creation.
- User and password setup.
- Disk encryption options.
- Bootloader setup.
- Installation progress and error reporting.

Existing operating systems and user files must never be deleted without explicit user approval.

---

## 14. Development Roadmap

### Phase 1: Foundation

Build the minimum usable Forynarch environment.

- Reproducible Arch ISO.
- Functional Hyprland session.
- Working terminal, launcher, and top bar.
- Basic file manager and networking.
- Reliable desktop startup.
- Tested boot on target hardware.
- Fallback environment for unsupported graphics configurations.

### Phase 2: Desktop Experience

Implement the distinguishing interaction features.

- Individual floating and tiling toggle.
- Workspace-level preferred modes.
- Workspace mode indicators.
- Independent per-monitor workspace mapping.
- Custom keyboard shortcut handling.
- Windows-like application switching.
- Persistent desktop preferences.

### Phase 3: Smart Storage

Develop the simplified storage experience.

- Automatic drive discovery.
- Drive aliases and friendly labels.
- File-manager integration.
- Configurable auto-mount policies.
- Safe unmount and eject.
- NTFS/exFAT interoperability tests.
- Encrypted and protected volume handling.

### Phase 4: Compatibility

Improve Windows interoperability.

- Wine integration.
- Windows application launcher support.
- Per-application compatibility testing.
- Windows boot entry discovery.
- Safe one-click reboot into another OS.
- Optional virtualized Windows integration.

### Phase 5: Optimization and Release

Prepare the distribution for broader use.

- Battery and thermal benchmarks.
- Performance tuning.
- Hardware compatibility testing.
- Installation and persistence testing.
- Recovery and rollback strategy.
- User documentation.
- Release packaging.

---

## 15. Success Criteria for the First Usable Release

The first usable release should satisfy these conditions:

1. The Live ISO boots on supported physical hardware.
2. A functional desktop session starts reliably.
3. A usable fallback exists when Hyprland cannot run.
4. Core desktop components work using tested package versions.
5. Floating and tiling can be toggled per window.
6. Preferred workspace modes influence newly launched windows.
7. Workspace indicators reflect the configured behavior.
8. Multi-monitor workspace shortcuts behave predictably.
9. File management and networking work without unnecessary configuration.
10. Supported drives can be accessed safely.
11. Power management works without conflicting services.
12. No destructive disk operations occur without confirmation.
13. Installation and persistence limitations are clearly documented.
14. The system can be rebuilt reproducibly from its source configurations.

Features not completed in the first release must be documented as planned rather than presented as functional.

---

## 16. Long-Term Vision

Forynarch aims to become a Linux desktop that feels lightweight, dependable, intuitive, and visually distinctive.

Its identity should come from the experience it provides rather than the number of features it includes.

Users should be able to enjoy a powerful terminal and a highly configurable Linux environment while also accessing drives, managing windows, and launching everyday applications without unnecessary complexity.

Windows interoperability should remain a major priority, but it must be implemented through technically sound methods.

**Forynarch should give users the freedom of Arch Linux without making everyday simplicity feel like a compromise.**


## 16 October 2026 ? user clarification: hotbar and window arrangements

The user requests a running-application hotbar integrated into the main panel,
sized to the applications shown. Hover must show selectable window previews
instead of account/window-count tooltips. Free floating must coexist with
Windows/macOS-style automatic layouts, including two-window tiling and shared
resizing. Application and settings/action icons must be distinguishable and use
appropriately licensed artwork. Complete the implementation and review, then
build a new ISO. The established Super+Arrow focus and Super+Shift+Arrow swap
bindings remain in force.
