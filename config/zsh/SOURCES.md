# Shell configuration sources

Forynarch ships a small Zsh configuration with its navy and blue palette.

- [xero/dotfiles](https://github.com/xero/dotfiles), by xero, CC0-1.0;
  reviewed revision `5204a2b74f9af6b979b88f71a696eca872396a33`.
  The numbered modules, separate history settings and minimal arrow prompt
  informed this adaptation. Forynarch's prompt and startup code are maintained
  here; xero's setup script, development environment, plugin downloads and Git
  prompt subprocesses are not installed. [License](../../licenses/xero-dotfiles-CC0.txt).
- [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
  MIT, version 0.7.1, tag revision
  `e52ee8ca55bcc56a17c828767a3f98f22a68d4eb`.
  Installed through Arch's signed `zsh-autosuggestions` package; loaded from
  `/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh`.
  [License](../../licenses/zsh-autosuggestions-MIT.txt).
- [Zsh](https://www.zsh.org/), the interactive shell; its upstream license is
  supplied by the Arch package under `/usr/share/licenses/zsh/`.
- [Alacritty](https://github.com/alacritty/alacritty), Apache-2.0 / MIT,
  the default terminal emulator. Its package supplies upstream licenses.
- [Fastfetch](https://github.com/fastfetch-cli/fastfetch), MIT,
  the one-shot terminal welcome. Its package supplies upstream licenses.

No shell startup runs `git clone`, contacts the network or installs packages.
Git and developer tools remain optional installer choices.
