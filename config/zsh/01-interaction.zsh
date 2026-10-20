HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
mkdir -p -- "${HISTFILE:h}"
HISTSIZE=5000
SAVEHIST=5000
setopt APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt INTERACTIVE_COMMENTS AUTO_CD
autoload -Uz compinit
compinit -d "${HISTFILE:h}/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors 'di=38;5;110' 'ln=38;5;153' 'ex=38;5;151'
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#8296b2'
ZSH_AUTOSUGGEST_STRATEGY=(history)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
