# Wi-Fi follow-up: R5.6.1

NetworkPage.qml and QuickControlActions.qml now read each device type directly
inside their QML bindings, so asynchronous device initialization and hotplug
can refresh the adapter lists. Ethernet uses the same discovery pattern.
The Quickshell 0.3.2 DeviceType.Wifi and DeviceType.Wired API is unchanged.

The installed core explicitly includes wireless-regdb and
linux-firmware-marvell, which were present in Live but missing from the
independent installed target. Existing Intel, Realtek, MediaTek, Atheros,
Broadcom and other standard firmware remains included by linux-firmware.
No additional daemon or developer toolchain is enabled.

The user requested an immediate ISO rebuild without additional QC. No new
hardware, UI, regression or memory test is claimed for this release. Build
completion and the downloaded ISO SHA-256 are recorded separately.

Build result: `mkarchiso` completed with exit status 0. The Windows copy is
3,839,197,184 bytes and its SHA-256 matches the builder output:
`bb22503013fe264faa3a849342be6396988e5c5be09d809b5d5c71577c3f99cf`.
The filename is `forynarch-2026.10.18-blue-hour-r5.6.1.iso`.

On physical hardware, the smallest follow-up is to open Wi-Fi after boot and
check discovery and scanning. If the adapter remains absent, capture
`lspci -nnk`, `lsusb`, `rfkill list`, `nmcli device`, and
`journalctl -b -k | grep -Ei 'firmware|wifi|wlan|iwl|rtw|ath|mt76|brcm'`.
An unsupported chipset or hardware radio block cannot be identified from a
VirtualBox Ethernet adapter.

References: [Quickshell device types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/DeviceType/),
[Arch wireless configuration](https://wiki.archlinux.org/title/Network_configuration/Wireless).
