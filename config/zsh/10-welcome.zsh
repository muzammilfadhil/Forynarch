# One welcome per terminal session, including when a nested Zsh is opened.
if [[ -t 0 && -t 1 && -z ${SSH_CONNECTION:-} && -z ${FORYNARCH_FETCH_SHOWN:-} && ${FORYNARCH_FASTFETCH:-1} != 0 && $TERM != dumb ]] && (( $+commands[fastfetch] )); then
    export FORYNARCH_FETCH_SHOWN=1
    fetch_config="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc"
    [[ -r "$fetch_config" ]] || fetch_config=/usr/share/forynarch/fastfetch.jsonc
    fastfetch --config "$fetch_config"
    unset fetch_config
fi
