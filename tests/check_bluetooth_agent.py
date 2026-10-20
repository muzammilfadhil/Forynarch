"""Exercise the actual compiled agent on a private D-Bus, without radios."""
import json
import os
import subprocess
import sys

environment = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"])
agent, mock = sys.argv[1:]
assert subprocess.run([agent, "invalid-device"], env=environment).returncode == 2
for mode in ("approve", "cancel", "eof", "terminate"):
    service = subprocess.Popen([mock], stdout=subprocess.PIPE, text=True, env=environment)
    process = None
    try:
        assert service.stdout.readline().strip() == "READY"
        process = subprocess.Popen([agent, "/org/bluez/hci0/dev_00_11_22_33_44_55"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=environment)
        events = []
        for line in process.stdout:
            event = json.loads(line)
            events.append(event["type"])
            if event["type"] == "confirm":
                assert event["code"] == "123456"
                if mode == "eof":
                    process.stdin.close()
                elif mode == "terminate":
                    process.terminate()
                else:
                    process.stdin.write(json.dumps({"approve": True} if mode == "approve" else {"cancel": True}) + "\n")
                    process.stdin.flush()
        assert process.wait(timeout=5) == 0
        assert events[-1] == ("connected" if mode == "approve" else "canceled"), (mode, events)
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        service.terminate()
        service.wait(timeout=5)
print("PASS: native D-Bus pairing approval/connect, cancellation, EOF, termination and invalid-device rejection")
