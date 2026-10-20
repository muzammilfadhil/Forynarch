# Default applications and Zsh review

## R4.5 artifact

`out/iso/forynarch-2026.10.16-blue-hour-r4.5.iso`, 3,966,468,096 bytes.
SHA256: `9a6f8b87c4d15720d8b11e49557acd03becf0142ccf59a7580e609f68807da2e`.
Host and builder hashes matched. Cold boot verified package versions, the Live
Zsh account, the Forynarch seed and absence of Foot/grml defaults. Further work
continues in [the R4.6 review](panel-audio-snap-review.md).

## Intent and affected files

Add Default Apps to Settings and use the selected terminal throughout desktop
launch paths. Replace the Foot default with Alacritty and configure Zsh,
autosuggestions and fastfetch for Live and newly installed accounts.

The implementation lives in `scripts/forynarch_defaults.py`,
`scripts/forynarch-default-apps.py`, `scripts/forynarch-terminal.py`,
`scripts/configure-terminal.sh`, the desktop integration and installer scripts,
`config/quickshell/forynarch/DefaultAppsPage.qml`, launcher/controller modules,
`config/alacritty`, `config/zsh`, `config/fastfetch` and the core manifests.
The wiki and README retain source credits and upstream licenses.

## Dependencies and decisions

Reviewed Arch packages: Alacritty 0.17.0-1, Zsh 5.9.2-1,
zsh-autosuggestions 0.7.1-1 and fastfetch 2.70.0-1. Hyprland remains 0.56.2-4.
Git, Node.js, npm and development toolchains remain optional. Existing documented
Python desktop runtime dependencies are unchanged.

Application associations use XDG MIME handlers. The terminal preference is an
atomic per-user JSON file. Discovery respects user desktop-entry overrides and
hidden applications; removed terminal choices fall back to an installed adapter.
No application-defaults daemon or shell plugin downloader was added.

The Live image previously inherited grml's Zsh templates. The build now removes
the grml package from the Live manifest and replaces verified untouched grml
and Forynarch factory templates. Other existing `.zshrc` files are retained. New account
creation chooses `/bin/zsh`; it does not migrate existing personal accounts.

Alacritty receives Mesa's software rendering fallback only on VirtualBox, where
the native EGL path failed when launched from the compositor. Physical machines
keep their native rendering environment. The desktop entry also uses the shared
terminal helper. Directory inheritance excludes the emulator's inherited
compositor controlling TTY when checking its child shell's PTY.

## Executed verification

- Arch builder: **182 tests, OK, 2 skipped**. Skips were the development-only
  Node JavaScript runner and a test requiring Zsh on the builder host.
- Target chroot: **2 shell configuration tests, OK, no skips**; existing user
  configuration survives repeat integration, and noninteractive startup emits
  no banner or history directory. Separate interactive checks reported
  `ZSH_INTERACTIVE_OK` and `ZSH_SCRIPT_OK`, with autosuggest widgets loaded and
  no startup errors.
- Windows: 8 default-app/ranking tests passed, including persistence, removed
  defaults, invalid selections, MIME arguments and paths containing spaces.
- Live VM: Default Apps loads in Settings; selecting Alacritty in the dropdown
  writes the expected per-user JSON preference. Searching `terminal` selects
  Alacritty. Real windows run Zsh with the blue prompt and fastfetch.
- Live VM: a shell that changes into `project after cd` passes that directory
  to a new Alacritty window: `ALACRITTY_ZSH_CWD_OK`.
- Live ownership checks: `.zshrc`, Alacritty and fastfetch configuration files
  are mode 644, owned by UID/GID 1000, and editable by Live user.

Early ISO candidates exposed the Live template and VM rendering issues above;
they are not release artifacts. Exact final artifact checks are recorded below
after rebuilding and booting the corrected image.

## Limits and next verification

The current installed-core idle RAM figure has **not** been remeasured for this
revision. The earlier R4.3 installed result (1.247 GB decimal, swap 0) is historical
evidence only. Fastfetch's Live display includes the Live environment and open
terminal, and is not an installed-core benchmark. The next memory gate requires
a fresh installed-core measurement with no terminal windows, using
`MemTotal - MemAvailable`, with swap recorded separately.

Kitty, WezTerm, Ghostty and Konsole adapter argument construction is supported;
their graphical launch paths have not been tested in this revision. Physical
hardware rendering and a fresh end-to-end installer run are also pending. The
installer shell argument was changed without exercising physical disk writes.
