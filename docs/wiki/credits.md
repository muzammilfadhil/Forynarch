# Credits and licensing

[0-ss/MacShell](https://github.com/0-ss/MacShell) by Rickky (MIT), revision
`18d9ceb682960aa96347e422e9b1578f1a4707cb`, supplies the adapted player-card
components and Liquid Glass shader. Forynarch changes their palette, blur source,
sampling budget, motion controls and MPRIS/preferences integration. This is an
optional style, not an import of the complete MacShell shell. The original
copyright and permission notice is retained in
[MacShell-MIT.txt](../../licenses/MacShell-MIT.txt); individual file provenance is
recorded in [MACSHELL-SOURCES.md](../../config/quickshell/forynarch/MACSHELL-SOURCES.md).

[audio_service_mpris](https://github.com/bdrazhzhov/audio-service-mpris) provides
Linux MPRIS support in the separately selected Mudil Music application.
Forynarch's 0.2.1 bridge patch adds monotonic Position, playback-rate handling,
Seeked signals and buffering-aware state; the original library license is
retained. `scripts/patch-mudil-mpris.py` reproduces these changes without
modifying a shared package cache.
[LRCLIB](https://lrclib.net/) supplies optional online lyric lookups. Their
availability does not imply every recording has lyrics. Screenshot and clipboard
integration uses [grim](https://gitlab.freedesktop.org/emersion/grim),
[slurp](https://github.com/emersion/slurp), and
[wl-clipboard](https://github.com/bugaevc/wl-clipboard).

Forynarch is created by **Muhammad Muzammil Fadhil**. The project builds on the
work below. Source licenses and package licenses stay with their respective
authors; visual inspiration is identified separately from copied code.

## Vendored code and assets

| Upstream | Use and attribution |
| --- | --- |
| [yeyushengfan258/Particle-circle-grub-theme](https://github.com/yeyushengfan258/Particle-circle-grub-theme) | Pinned window/1080p GRUB theme assets, adapted for Forynarch entries and display fallback. [GPL license](../../licenses/Particle-circle-GPL-3.0.txt), [font source and provenance](../../assets/grub/particle-circle-source/UPSTREAM.md) retained. |
| [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) | Hyprland Kath login theme, adapted with Forynarch colors, power controls, fade and account behavior. GPL-3.0-or-later headers and LICENSE retained. Pinned revision and changes: [UPSTREAM.md](../../config/sddm/themes/forynarch-kath/UPSTREAM.md). |
| [MarianArlt/sddm-sugar-dark](https://github.com/MarianArlt/sddm-sugar-dark) | Original theme lineage credited by the Astronaut theme's retained source headers. |
| [tabler/tabler-icons](https://github.com/tabler/tabler-icons) | Selected action and application SVGs, recolored ice blue. MIT license retained in [licenses/Tabler-Icons.txt](../../licenses/Tabler-Icons.txt); exact sources and revision in [SOURCES.md](../../assets/icons/Forynarch/SOURCES.md). |
| [Unicode](https://www.unicode.org/) | Emoji catalog data; [Unicode license](../../licenses/Unicode.txt) retained. |
| [googlefonts/noto-emoji](https://github.com/googlefonts/noto-emoji) | Noto Color Emoji supplied through its Arch package. Package license applies. Apple's emoji font is not redistributed. |

The Kath video and fallback image follow the upstream asset lineage, including
MotionBgs. The user-supplied video matches the upstream bytes. The theme's code
license does not independently establish redistribution rights for the artwork;
that remains a public-release review item, recorded in UPSTREAM.md. No claim is
made that all assets are copyright-free.

## Platform and runtime projects

| Project | Role |
| --- | --- |
| [Arch Linux](https://archlinux.org/) and [archlinux/archiso](https://gitlab.archlinux.org/archlinux/archiso) | Base packages and Live ISO build profile/tooling |
| [archlinux/mkinitcpio](https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio) and [mkinitcpio-archiso](https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio-archiso) | Installed and Live initramfs hooks |
| [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) | Compositor, window/workspace control and motion |
| [quickshell-mirror/quickshell](https://github.com/quickshell-mirror/quickshell) and [Qt](https://code.qt.io/) | Desktop shell, widgets, settings and installer UI |
| [Alexays/Waybar](https://github.com/Alexays/Waybar) | Classic panel option and earlier panel development |
| [xfce-mirror/thunar](https://github.com/xfce-mirror/thunar) | File Manager runtime, with Forynarch branding and preferences integration |
| [sddm/sddm](https://github.com/sddm/sddm) | Graphical login and session lifecycle |
| [Plymouth](https://gitlab.freedesktop.org/plymouth/plymouth) | Early boot rendering and progress engine; Forynarch's theme is original source |
| [swaywm/swaybg](https://github.com/swaywm/swaybg), [emersion/mako](https://github.com/emersion/mako), [foot](https://codeberg.org/dnkl/foot) and [fuzzel](https://codeberg.org/dnkl/fuzzel) | Wallpaper, notifications, terminal and classic launcher |
| [karlstav/cava](https://github.com/karlstav/cava) | On-demand music spectrum |
| [systemd/systemd](https://github.com/systemd/systemd), [NetworkManager](https://gitlab.freedesktop.org/NetworkManager/NetworkManager), [bluez/bluez](https://github.com/bluez/bluez), [PipeWire](https://gitlab.freedesktop.org/pipewire/pipewire), [WirePlumber](https://gitlab.freedesktop.org/pipewire/wireplumber), [storaged-project/udisks](https://github.com/storaged-project/udisks) and [KDE Partition Manager](https://invent.kde.org/system/partitionmanager) | Services and hardware/storage integration |

This list identifies the main direct integrations. The ISO's package list and
installed package database provide the complete dependency inventory. Packaged
upstreams keep their licenses in `/usr/share/licenses/`; vendoring is not implied
for every runtime dependency.

## References and development tools

- [pctrade/end4-pC](https://github.com/pctrade/end4-pC), especially screenshot 3,
  supplied the user's visual reference. Its upstream
  [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) / illogical-impulse
  is credited as the source project's lineage. Their shell was not copied wholesale
  into Forynarch. [Analysis and scope](../end4-reference-analysis.md).
- [basecamp/omarchy](https://github.com/basecamp/omarchy) inspired compatible
  hotkeys and the web-app install/remove workflow. Forynarch keeps its own user
  overrides and isolated browser profiles. [Hotkey manual](https://omarchy.org/manual/hotkeys/).
- [homarr-labs/dashboard-icons](https://github.com/homarr-labs/dashboard-icons)
  was suggested as an optional web-app icon source. The current helper fetches
  a user-specified icon or a site's touch icon; Dashboard Icons is not bundled.
- [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) supplied
  development-time UI/copy review guidance. It is not an OS runtime dependency.
- [Calamares](https://codeberg.org/Calamares/calamares) documentation informed early
  installer architecture proposals. The current guided installer is Forynarch's
  own implementation; wishlist catalogs are not claimed to be tested Calamares config.
- NVIDIA's [open GPU kernel modules](https://github.com/NVIDIA/open-gpu-kernel-modules)
  were consulted for optional driver planning; drivers remain explicit choices.
- GIPHY is an optional service for GIF search; its attribution and API requirements
  apply. Third-party web-app logos and favicons retain their owners' rights.

## Project-wide license status

The repository currently has no top-level LICENSE declaring a license for all
Forynarch-authored code. Public development and source availability alone do not
resolve that omission. This wiki records it rather than assigning the creator's
work a license silently. A project-level license decision and the Kath artwork
rights review remain necessary before presenting the whole project as a fully
licensed public distribution. Retained third-party licenses remain effective.

### Terminal and shell

The default terminal is [Alacritty](https://github.com/alacritty/alacritty),
with [Zsh](https://www.zsh.org/),
[zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
and [Fastfetch](https://github.com/fastfetch-cli/fastfetch).
[xero/dotfiles](https://github.com/xero/dotfiles) (CC0) inspired the modular shell
configuration and minimal prompt. See the pinned source revisions and retained
licenses in [shell source credits](../../config/zsh/SOURCES.md).
Foot is retained in historical credits for earlier builds; it is no longer a
default/core package. Git and development toolchains remain opt-in.

[Chafa](https://github.com/hpjansson/chafa) and [librsvg](https://gitlab.gnome.org/GNOME/librsvg) render the project SVG into terminal artwork at build time. Chafa is a builder dependency only; the generated artwork depicts the Forynarch logo.

## Floating titlebars

[Hyprbars](https://github.com/hyprwm/hyprland-plugins/tree/7644cecdb947060682891a0db2a0cdc5c0b9e704/hyprbars), copyright Hypr Development, BSD 3-Clause. The compiled titlebar extension uses the upstream pin for Hyprland 0.56.2 and the Forynarch window-control helper. R5.8.7 adds the downstream `hyprbars:title` per-window name override; `scripts/patch-titlebar-app-names.py` records the source changes. License: `licenses/hyprbars-BSD-3-Clause.txt`. [yay](https://github.com/Jguer/yay) is used only by the explicit Chrome/AUR patch workflow.

R5.8.8 extends the same pinned Hyprbars source with matching paint/damage bounds and previous-region cleanup (`scripts/patch-titlebar-damage.py`). The BSD license and upstream authorship remain unchanged.

## Public release preparation

Public builds exclude the local Kath MP4/PNG and separately maintained Mudil Music binary pending their redistribution/source review. Forynarch navy artwork replaces the login background. Theme code and notices remain included. GNU Unifont uses its separate SIL OFL 1.1 option; see [the font notice](../../licenses/Unifont-OFL-1.1.txt). See [publishing](../publishing.md) for the original-code license proposal and clean-history export.
