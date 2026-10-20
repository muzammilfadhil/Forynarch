# Wallpaper, audio and Bluetooth

## Wallpaper

In File Manager, right-click one image and choose **Set as wallpaper**. The action
calls `forynarch-wallpaper set IMAGE` without sudo. A managed copy is kept under
`~/.local/share/forynarch/wallpapers/`; its selection is stored in
`~/.config/forynarch/wallpaper.json`. The wallpaper remains available after its
original USB drive or downloaded file is removed. Login restores the selection.

One user service runs the same swaybg renderer used by the default desktop.
The Python launcher is replaced by swaybg and does not remain resident. Failed
image rendering restores the previous choice. Desktop integration renames
`thunar-wallpaper-plugin.so` to `.so.disabled`, preserving the original module.
Its XFCE/GNOME-specific action cannot control a Hyprland background. Other
extensions remain available. The existing pacman desktop hook repeats this
change after Thunar upgrades; package file verification reports the diverted
module. Restart File Manager after changing this integration in a live session.

## Sound and app devices

The bar's speaker opens a compact audio panel in either Control Center style.
It does not automatically open Settings. **All sound settings** remains an
explicit action. Output and microphone defaults can be selected separately.

While an app plays or records, its device choices offer:

- **System default:** follow the current system device and later default changes.
- **App settings:** remove Forynarch's stream override and use the app's policy.
- A specific connected device for playback or recording.

Volume and mute stay independent of device routing. Nothing reroutes an app
merely because the panel opens. App-controlled monitor capture and strict
device requirements are preserved; those cases may require the app's own
settings. Capture-only applications also appear. Only existing user-session
streams are accepted; stale node IDs and disconnected devices are rejected.

The helper uses WirePlumber's `target.object` metadata. Default routing uses
the zero target's normal fallback policy, and app-managed routing removes the
metadata override. Native tests verify both playback/capture links and default
changes. Discovery refresh runs only while an audio panel is open; there is no
new routing daemon. WirePlumber manages its usual stream/device restoration.

References: [WirePlumber linking settings](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html),
[linking implementation](https://github.com/PipeWire/wireplumber/blob/0.5.18/src/scripts/linking/find-defined-target.lua),
[PipeWire metadata CLI](https://docs.pipewire.org/page_man_pw-metadata_1.html).

## Bluetooth

Settings checks the Bluetooth service and software/hardware radio blocks. An
authenticated **Enable Bluetooth service and radio** action starts BlueZ and
clears a software block. Hardware switches and unavailable firmware cannot be
overridden by that action. A scan that BlueZ does not actually start now reports
failure instead of indefinitely claiming discovery is active.

Pairing still confirms the device's PIN/passkey through the existing BlueZ
agent. Scanning stops on timeout or page exit. VirtualBox does not expose a
Bluetooth adapter by default; real radio/pairing validation needs physical
hardware or an explicitly attached USB Bluetooth adapter. The UI reports this
case rather than simulating devices.

## Fresh packages during build

Every approved `forynarch.sh build` performs a full stable Arch builder update
before target/Live package resolution. Fresh roots use current signed packages;
the build does not perform partial upgrades. Runtime API/version checks still
stop the build when an upstream change needs review. Hyprland update-news popups
are disabled with its documented `ecosystem.no_update_news` option; this does not
suppress compositor configuration errors or package-update failures.
