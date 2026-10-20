# Displays, audio hardware and lyrics

## Displays

Open **Settings → Displays**. Select the monitor, then choose **Resolution** and **Refresh rate** separately. Only modes reported by the monitor/compositor are offered. Scale choices must produce whole logical pixels.

Select **Preview changes**. A centered confirmation offers **Keep changes** and **Revert**. An independent watchdog restores the previous configuration after 15 seconds unless you keep it. Escape also reverts. Confirmed settings are saved in the user's Hyprland monitor configuration.

If a mode is absent, the driver or monitor did not advertise it. This interface does not invent custom timings. Physical AMD/NVIDIA/Intel outputs and multi-monitor combinations need their own verification; VirtualBox modes do not certify them.

## Audio hardware

Open **Settings → Sound → Audio hardware**. Each detected audio card has an enable switch and a list of available profiles. **Off** disables that card's input and output nodes; it does not merely mute volume. Enabling restores the previous available profile or selects an available profile if it changed. Unplugged devices are refreshed while this page is visible.

Default input/output selectors and per-application routing remain separate. Switching profiles can recreate device nodes, so reselect an application's output if its previous node disappears. Bluetooth profiles depend on the headset and its negotiated connection.

## Music and lyrics

Select the music player and enable **Lyrics** in music-widget settings. Mudil Music is detected through its MPRIS identity; other MPRIS players also work. Embedded `xesam:asText` lyrics take precedence. Otherwise the helper normalizes common video-title decorations, tries a metadata match, then searches with title, artist and duration checks.

Lyrics are requested only while the music widget and its lyrics option are enabled and the widget is not being edited. Disabling lyrics or hiding the widget cancels the helper and stops lookups. Position updates do not repeat network requests.

Successful results are cached for 30 days, missing lyrics for 6 hours, and temporary service failures for 60 seconds. The cache is limited to 64 entries and 8 MiB in `~/.cache/forynarch/lyrics`. Delete that directory to clear it. Unavailable lyrics do not prevent music controls from working. Matching depends on the track metadata and provider coverage; it is not guaranteed for every song.

Lyrics source: [LRCLIB API](https://lrclib.net/docs). Player metadata: [MPRIS specification](https://specifications.freedesktop.org/mpris/latest/Track_List_Interface.html#Mapping:Metadata_Map).
