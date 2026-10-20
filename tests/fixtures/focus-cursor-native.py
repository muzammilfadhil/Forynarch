#!/usr/bin/env python3
"""Exercise actual focus dispatch and cursor coordinates in a disposable VM."""
import json
import os
from pathlib import Path
import subprocess
import time

assert os.getuid() == 1000
expected_uuid = os.environ.get('FORYNARCH_QA_PRODUCT_UUID', '')
assert expected_uuid and Path('/sys/class/dmi/id/product_uuid').read_text().strip() == expected_uuid

def command(*args):
    return subprocess.check_output(args, text=True, timeout=15)

def query(name):
    return json.loads(command("hyprctl", "-j", name))

def dispatch(value):
    assert command("hyprctl", "dispatch", value).strip() == "ok"

def focus(address):
    dispatch('hl.dsp.focus({window="address:' + address + '"})')
    time.sleep(.25)
    assert query("activewindow").get("address") == address, ("Focus did not stay on target",query("activewindow"))

original = query("activeworkspace")["id"]
command("qs", "-c", "forynarch", "ipc", "call", "appearance", "closePopups")
time.sleep(.3)
assert not any(c["workspace"]["id"] == 9787 for c in query("clients"))
processes = []
try:
    dispatch("hl.dsp.focus({workspace=9787,on_current_monitor=true})")
    for name in ("ForynarchFocusFixtureA", "ForynarchFocusFixtureB"):
        processes.append(subprocess.Popen(["alacritty", "--class", name, "-e", "sleep", "60"],
            env=dict(os.environ, LIBGL_ALWAYS_SOFTWARE="1"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        windows = [c for c in query("clients") if c["class"].startswith("ForynarchFocusFixture")]
        if len(windows) == 2:
            break
        time.sleep(.1)
    assert len(windows) == 2
    for window in windows:
        focus(next(other["address"] for other in windows if other["address"] != window["address"]))
        dispatch("hl.dsp.cursor.move({x=50,y=700})")
        focus(window["address"])
        current = next(c for c in query("clients") if c["address"] == window["address"])
        cursor = query("cursorpos")
        assert abs(cursor["x"] - current["at"][0] - current["size"][0]/2) <= 2, (cursor,current)
        assert abs(cursor["y"] - current["at"][1] - current["size"][1]/2) <= 2, (cursor,current)
    command("forynarch-window-mode", "floating", "--apply-open")
    time.sleep(.3)
    dispatch("hl.dsp.cursor.move({x=50,y=700})")
    before = query("cursorpos")
    for window in windows:
        focus(window["address"])
        assert query("cursorpos") == before
    command("forynarch-window-switcher", "reset")
    command("forynarch-window-switcher", "next")
    assert query("cursorpos") == before
    print("PASS tiled focus centers cursor; floating focus and Alt+Tab preserve cursor position")
finally:
    command("forynarch-window-mode", "dwindle", "--apply-open")
    for process in processes:
        process.terminate()
    dispatch("hl.dsp.focus({workspace="+str(original)+",on_current_monitor=true})")
