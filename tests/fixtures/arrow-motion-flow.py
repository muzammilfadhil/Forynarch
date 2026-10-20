#!/usr/bin/env python3
"""Run phases around physical VirtualBox key input in a disposable workspace."""
import json
from pathlib import Path
import subprocess
import sys
import time

STATE = Path("/tmp/forynarch-arrow-qa.json")


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, check=True, timeout=15).stdout


def query(name):
    return json.loads(run("hyprctl", "-j", name))


def wait(predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.12)
    raise AssertionError("Native window state did not converge")


def enabled():
    option = json.loads(run("hyprctl", "-j", "getoption", "animations:enabled"))
    return option.get("bool", option.get("int", option.get("value")))


def blur_enabled():
    option = json.loads(run("hyprctl", "-j", "getoption", "decoration:blur:enabled"))
    return option.get("bool", option.get("int", option.get("value")))


phase = sys.argv[1]
if phase == "inspect":
    print(run("hyprctl", "-j", "getoption", "animations:enabled"))
    print(run("hyprctl", "-j", "animations"))
elif phase == "motion":
    for value in (False, True):
        run("qs", "-c", "forynarch", "ipc", "call", "appearance", "setMotion", str(value).lower())
        wait(lambda: enabled() == int(value))
        run("hyprctl", "reload")
        wait(lambda: enabled() == int(value))
    assert not run("hyprctl", "configerrors").strip()
    print("PASS: motion on/off survives native config reload and respects reduced motion")
    for value in (False, True):
        run("qs", "-c", "forynarch", "ipc", "call", "appearance", "setGlass", str(value).lower())
        wait(lambda: blur_enabled() == value)
        run("hyprctl", "reload")
        wait(lambda: blur_enabled() == value)
    print("PASS: glass on/off survives native config reload")
elif phase in {"prepare", "prepare-floating", "prepare-stacked"}:
    run("qs", "-c", "forynarch", "ipc", "call", "appearance", "closeSettings")
    original = query("activeworkspace")["id"]
    occupied = {c["workspace"]["id"] for c in query("clients")}
    workspace = next(i for i in range(161, 181) if i not in occupied)
    run("hyprctl", "dispatch", 'hl.dsp.focus({workspace=' + str(workspace) + '})')
    run("forynarch-window-mode", "floating" if phase == "prepare-stacked" else "hybrid")
    for index in range(2):
        subprocess.Popen(["foot", "--app-id=forynarch-arrow-qa", "--title=Arrow QA " + str(index), "sleep", "300"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    clients = wait(lambda: [c for c in query("clients") if c["class"] == "forynarch-arrow-qa"] if len([c for c in query("clients") if c["class"] == "forynarch-arrow-qa"]) == 2 else [])
    if phase == "prepare-floating":
        run("forynarch-window-control", "toggle-all")
        clients = [c for c in query("clients") if c["class"] == "forynarch-arrow-qa"]
    clients.sort(key=lambda c:c["at"][0])
    if phase != "prepare-stacked":
        assert clients[0]["at"][0] < clients[1]["at"][0]
    STATE.write_text(json.dumps({"original":original,"left":clients[0]["address"],"right":clients[1]["address"],"positions":{c["address"]:c["at"] for c in clients}}))
    run("hyprctl", "dispatch", 'hl.dsp.focus({window="address:' + clients[0]["address"] + '"})')
    print("READY: press Super + Right")
elif phase in {"focus", "swap"}:
    state = json.loads(STATE.read_text())
    assert query("activewindow")["address"] == state["right"]
    clients = {c["address"]:c for c in query("clients")}
    positions = {address:clients[address]["at"] for address in state["positions"]}
    if phase == "focus":
        assert positions == state["positions"], "Focus must not swap or move windows"
        print("PASS: physical Super + Right changes focus without moving windows")
    else:
        assert positions[state["right"]][0] < positions[state["left"]][0]
        print("PASS: physical Super + Shift + Left swaps windows and preserves active client")
elif phase == "cleanup":
    state = json.loads(STATE.read_text())
    for address in (state["left"],state["right"]):
        run("forynarch-window-control", "close", address)
    run("hyprctl", "dispatch", 'hl.dsp.focus({workspace=' + str(state["original"]) + '})')
    STATE.unlink()
else:
    raise ValueError("Unknown native QA phase")
