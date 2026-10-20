# Default apps and terminal

Open **Settings > Default Apps** to choose installed applications for the
terminal, web links, folders, text, PDF, images, audio and video. Use **Refresh
installed apps** after installing or removing software. Empty categories remain
available without installing a browser or another optional application.

File and link associations use the XDG MIME database. The browser choice sets
HTTP, HTTPS and HTML handlers. Media choices cover the common formats listed by
`forynarch-default-apps status`; an application's advanced preferences can set
additional formats. These associations affect applications that honor XDG.

The terminal choice is stored in
`~/.config/forynarch/default-apps.json`. Supported terminal adapters are Alacritty,
Kitty, WezTerm, Ghostty and Konsole. The default is Alacritty. Missing or removed
choices fall back to an installed supported terminal. The launcher prioritizes
this choice for a **terminal** search. Terminal shortcuts, widgets, folder actions
and applications marked `Terminal=true` use `forynarch-terminal`.

When opening another terminal over an existing terminal, the helper reads its
local foreground shell directory. Ambiguous process trees and inaccessible
directories fall back to Home. Commands and paths are passed as separate
arguments. No background directory watcher is required.

## Zsh

New installed accounts and the Live account use Zsh. This does not change the
shell of an existing personal account. Alacritty's factory configuration is at
`~/.config/alacritty/alacritty.toml`; its shell and palette can be edited there.
The shared defaults seed `~/.zshrc` without replacing an existing file.

`~/.zshrc` sources `/usr/share/forynarch/zsh/init.zsh`. That file loads numbered
system modules, followed by user `*.zsh` files in
`~/.config/forynarch/zsh/`. Add overrides there or edit `~/.zshrc` directly.
History lives in `~/.local/state/zsh/history` (or `$XDG_STATE_HOME/zsh/history`).
Commands beginning with a space are excluded from history.

Autosuggestions use your local history. Press Right at the end of a command to
accept its suggestion. The plugin comes from Arch's `zsh-autosuggestions` package;
Oh My Zsh and Git are not required. For a manually managed Oh My Zsh installation,
the upstream example remains:

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
```

This command is documentation only; the OS does not run it.

Fastfetch runs once in a new interactive local terminal, with an ASCII rendition
of Forynarch's four-point mark. It does not run for scripts, SSH sessions or nested
Zsh sessions. The default fields are OS, Host, Kernel, Uptime, CPU, Memory and GPU.
Edit `~/.config/fastfetch/config.jsonc` to customize it. To disable
the welcome, put `export FORYNARCH_FASTFETCH=0` **before** the source line in
`~/.zshrc`. It is a one-shot command, with no resident service.

See [shell source credits](../../config/zsh/SOURCES.md). Native verification must
include a newly created account, terminal search ordering, MIME associations,
directory inheritance, interactive and noninteractive Zsh, and idle RAM measured
separately from an open terminal. A Live measurement is not an installed-core
memory benchmark.
