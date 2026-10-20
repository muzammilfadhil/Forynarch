[[ -o interactive ]] || return

# Modular shell setup inspired by xero/dotfiles (CC0); see SOURCES.md.
typeset -g FORYNARCH_ZSH_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/forynarch/zsh
for config in /usr/share/forynarch/zsh/[0-9]*.zsh(N); do
    source "$config"
done
for config in "$FORYNARCH_ZSH_DIR"/*.zsh(N); do
    source "$config"
done
unset config
