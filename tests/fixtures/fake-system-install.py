#!/usr/bin/python
"""Private stdin protocol fixture; never invokes the real installer."""
import json
import os
import sys
import time

assert sys.argv[1:] == ["/usr/local/libexec/forynarch-install-system"]
request = json.loads(sys.stdin.readline())
assert request["password"] == request["confirmation"] == "Fixture password 123!"
assert request["consent"] == "ERASE /dev/qa-not-a-real-disk"
assert request["plan"]["selectedGroups"] == []
assert "password" not in request["plan"]
assert request["plan"]["diskId"] == "serial:fixture-only"
failure = os.environ.get("FORYNARCH_EXECUTE_FIXTURE_FAILURE")
print(json.dumps(dict(kind="log", text="Fixture installer output: downloading selected packages")), flush=True)
if failure:
    time.sleep(0.8)
    if failure == "transport":
        print(json.dumps(dict(stage="download", message="Fixture download", diskMayHaveChanged=False)), flush=True)
        print("fixture helper failed without final report", file=sys.stderr, flush=True)
        sys.exit(23)
    changed = failure == "flatpak"
    print(json.dumps(dict(stage="failed", message="Fixture installation stopped", failedStage=failure,
                          exitCode=17, diskMayHaveChanged=changed, details="error: fixture download unavailable",
                          logPath="/run/forynarch-installation/installation.log")), flush=True)
    sys.exit(17)
for stage in ["prepare", "partition", "extract", "verify", "complete"]:
    print(json.dumps(dict(stage=stage, message="Fixture: " + stage)), flush=True)
    time.sleep(0.15)
