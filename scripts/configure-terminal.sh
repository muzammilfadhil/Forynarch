#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 1 && -d "$1/etc" ]] || exit 2
root="$(realpath -e -- "$1")"
[[ "$root" != / ]] || { echo 'A staged root is required.' >&2; exit 2; }
mkdir -p "$root/usr/share/forynarch/zsh"
install -m644 "$ROOT"/config/zsh/*.zsh "$root/usr/share/forynarch/zsh/"
install -Dm644 "$ROOT/config/fastfetch/config.jsonc" "$root/usr/share/forynarch/fastfetch.jsonc"
for home in "$root/etc/skel" "$root/root" "$root/home/liveuser"; do
    [[ -d "$home" ]] || continue
    for file in .zshrc .config/alacritty/alacritty.toml .config/fastfetch/config.jsonc; do
        case "$file" in
            .zshrc) source="$ROOT/config/zsh/.zshrc" ;;
            .config/alacritty/*) source="$ROOT/config/alacritty/alacritty.toml" ;;
            *) source="$ROOT/config/fastfetch/config.jsonc" ;;
        esac
        replace=false
        if [[ "$file" == .zshrc && -f "$home/$file" ]]; then
            case "$(sha256sum "$home/$file" | cut -d' ' -f1)" in
                12713ac2bca0cc69cdb6fa5ee68abdeb4c659f3508187b7ae8867d3ae173eca9|aec585092ae154b7ab22416092c528f8bad1df0ae68a995a37a954a7db6ca98e) replace=true ;;
            esac
        fi
        if [[ "$file" == .config/fastfetch/config.jsonc && -f "$home/$file" ]]; then
            case "$(sha256sum "$home/$file" | cut -d' ' -f1)" in
                b3fb584b3ddae2e92f898ee2ea2e6e934eba9a00b32b36b2b0cee5e05d302030|42e627d2eb0c08b07275be58e158054e1268d6ebd9e6e6e201494d9a8cf08ca7) replace=true ;;
            esac
        fi
        if [[ ! -e "$home/$file" || "$replace" == true ]]; then
            install -Dm644 "$source" "$home/$file"
        fi
    done
    # Remove the retired factory terminal config only from newly built homes.
    if [[ -f "$home/.config/foot/foot.ini" ]] && [[ $(sha256sum "$home/.config/foot/foot.ini" | cut -d' ' -f1) == 3db8d314eb0d67f9dd8679ad0d13e005e3b98fc032611f4187e37a47f2decaa9 ]]; then
        rm -- "$home/.config/foot/foot.ini"
        rmdir -- "$home/.config/foot" 2>/dev/null || true
    fi
done
