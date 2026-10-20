#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d /tmp/forynarch-agent-qa.XXXXXXXX)"
trap 'rm -rf -- "$temporary"' EXIT
bash "$ROOT/scripts/build-bluetooth-agent.sh" "$temporary/agent"
mkdir "$temporary/mock"
cd "$temporary/mock"
qmake6 "$ROOT/tests/fixtures/bluez-mock.pro"
make -j2
timeout 25 dbus-run-session -- python "$ROOT/tests/check_bluetooth_agent.py" "$temporary/agent/forynarch-bluetooth-pair" "$temporary/mock/bluez-mock"
