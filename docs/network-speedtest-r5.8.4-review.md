# Network speed-test button, R5.8.4

Settings > Network now has an **Internet speed** row with **Run speed test**.
It opens [Fast.com in English](https://fast.com/en/) through the system's default
browser. The speed measurement runs in the browser.

The action uses the existing SettingRow and ActionButton, navy palette, network
glyph, 44 px button height, hover motion and keyboard handling. The compact
Control Center Wi-Fi view keeps its current layout. If the URL handler reports
failure, the page directs the user to install/select a browser in Default Apps.
The action does not install a browser, add packages or run background tests.

Affected source: `config/quickshell/forynarch/NetworkPage.qml`.
User documentation: `docs/settings-and-hotkeys.md`.
Runtime remains Quickshell 0.3.2 / Qt 6.12 with the frozen 18 October core.

Quick verification: whitespace check passed and the actual Network settings page
rendered the new action in the existing Live VM, alongside its Ethernet status.
No full regression suite or internet throughput measurement was run for this
small change. Actual browser launch, transfer speed and the missing-browser
error path still need acceptance when the button is used. Existing browser
configuration and network access are required.

The UI keeps the established energy 2 / rhythm 2 / motion 2 direction and reuses
existing focus, disabled, hover and spacing conventions. No visual assets,
continuous effects or fabricated speed readings were added.

## Artifact verification

The final ISO is `forynarch-2026.10.18-blue-hour-r5.8.4.iso`, 3839197184 bytes.
Builder and Windows SHA-256 matched:
`8bea7e12fbd845d3ba60e6e26fcef63dbc52938958398bf1db243b2dd63cf607`.

Fourteen Live source hashes and eleven target-bundle hashes matched, including
NetworkPage.qml. The independent core still has 573 packages and excludes
unselected developer groups. No fresh ISO boot or full regression suite was
repeated for this small change. The Network page was checked in the existing VM
with the updated source; the final image was checked against that exact source.
