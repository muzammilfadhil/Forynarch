#!/usr/bin/env bash
# Shared guards; sourcing this file does not install or alter anything.

require_arch_environment() {
  if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "Error: use an Arch Linux x86_64 VM, not Windows/Git Bash." >&2
    return 1
  fi
  if [[ ! -r /etc/os-release ]] || ! grep -qx 'ID=arch' /etc/os-release; then
    echo "Error: an Arch Linux builder is required." >&2
    return 1
  fi
  if ! command -v findmnt >/dev/null 2>&1; then
    echo "Error: findmnt is required to validate the build filesystem." >&2
    return 1
  fi
  local filesystem
  filesystem="$(findmnt -n -o FSTYPE -T "$ROOT")" || return 1
  case "$filesystem" in
    ext2|ext3|ext4|btrfs|xfs|f2fs|zfs) ;;
    *) echo "Error: build source must be on a Linux-native filesystem; found $filesystem." >&2
       return 1 ;;
  esac
}

require_local_destination() {
  local target="$1" resolved
  resolved="$(realpath -m "$target")" || return 1
  if [[ "$resolved" != "$ROOT/"* || -L "$target" ]]; then
    echo "Error: destination must remain inside the repository and not be a symlink." >&2
    return 1
  fi
}
