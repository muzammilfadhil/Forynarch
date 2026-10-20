#!/usr/bin/env bash
# Isolated QML test process. Never installed into a desktop image.
set -euo pipefail
[[ $# == 1 && "$1" == /org/bluez/hci0/dev_00_11_22_33_44_55 ]] || exit 2
printf '{"type":"confirm","code":"123456"}\n'
IFS= read -r answer
if jq -e '.approve == true' >/dev/null <<< "$answer"; then
    printf '{"type":"connected"}\n'
else
    printf '{"type":"canceled"}\n'
fi
