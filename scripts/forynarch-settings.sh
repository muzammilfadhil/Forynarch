#!/usr/bin/env bash
set -euo pipefail
page="${1:-Appearance}"
case "$page" in Appearance|Panel|Desktop|Files|"Default Apps"|"Date & Time"|"Notifications"|"Virtual Machines"|Network|Bluetooth|Sound|Displays|Power|Input|Storage|Privacy|Shortcuts|About) ;; *) exit 2 ;; esac
if command -v qs >/dev/null && qs -c forynarch ipc call appearance openPage "$page" >/dev/null 2>&1; then exit 0; fi
exec notify-send 'Forynarch Settings' 'Start the Glass desktop session to open appearance settings.'
