#!/usr/bin/env python3
"""Real Hyprland session QA on a vacant workspace; closes only its own clients."""
import json
import subprocess
import time


def run(*args, check=True):
    return subprocess.run(args, text=True, capture_output=True, check=check, timeout=30)


def query(name):
    return json.loads(run("hyprctl", "-j", name).stdout)


def wait(predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.12)
    raise AssertionError("Timed out waiting for the compositor")


def action(verb, address=None):
    return run("forynarch-window-control", verb, *([address] if address else []))


def client(address):
    return next((c for c in query("clients") if c["address"] == address), None)


original_workspace = query("activeworkspace")["id"]
occupied = {c["workspace"]["id"] for c in query("clients")}
workspace = next(number for number in range(151, 201) if number not in occupied)
owned = []
files_id = None
try:
    run("qs", "-c", "forynarch", "ipc", "call", "appearance", "closeSettings")
    run("hyprctl", "dispatch", 'hl.dsp.focus({workspace=' + str(workspace) + '})')
    run("forynarch-window-mode", "hybrid")
    for index in range(2):
        subprocess.Popen(["foot", "--app-id=forynarch-controls-qa", "--title=Window controls QA " + str(index), "sleep", "300"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    owned = wait(lambda: [c["address"] for c in query("clients") if c["class"] == "forynarch-controls-qa"] if len([c for c in query("clients") if c["class"] == "forynarch-controls-qa"]) == 2 else [])
    first, second = owned
    run("hyprctl", "dispatch", 'hl.dsp.window.float({window="address:' + first + '",action="on"})')
    prior = {a:client(a)["floating"] for a in owned}
    assert sorted(prior.values()) == [False, True]
    action("toggle-all")
    wait(lambda: all(client(a)["floating"] for a in owned))
    assert client(second)["size"][0] < query("monitors")[0]["width"]
    wait(lambda: len(json.loads(run("qs", "-c", "forynarch", "ipc", "call", "appearance", "windows").stdout)["windows"]) == 2)
    action("toggle-all")
    assert {a:client(a)["floating"] for a in owned} == prior
    print("PASS: workspace floating toggle restores manual floating overrides")
    action("toggle-all")
    action("minimize", first)
    wait(lambda: client(first)["workspace"]["name"] == "special:forynarch-minimized")
    state = json.loads(action("status").stdout)
    assert next(c for c in state["windows"] if c["address"] == first)["minimized"]
    action("activate", first)
    wait(lambda: client(first)["workspace"]["id"] == workspace)
    for verb, target in (("maximize",1),("fullscreen",2)):
        action(verb, first)
        wait(lambda: client(first)["fullscreen"] == target)
        action(verb, first)
        wait(lambda: client(first)["fullscreen"] == 0)
    action("minimize", first)
    action("restore-last")
    wait(lambda: client(first)["workspace"]["id"] == workspace)
    print("PASS: minimize, application-list restore, restore-last, maximize and fullscreen round trips")
    rows = json.loads(run("forynarch-shortcut-config", "status").stdout)["rows"]
    files_id = next(r["id"] for r in rows if r["keys"] == "SUPER + E")
    failed = run("forynarch-shortcut-config", "set", files_id, "SUPER + SPACE", check=False)
    assert failed.returncode != 0 and "conflicts" in failed.stderr
    run("hyprctl", "eval", 'hl.bind("SUPER + CTRL + F11",hl.dsp.exec_cmd("true"),{description="QA external binding"})')
    failed = json.loads(run("forynarch-shortcut-config", "check", files_id, "CTRL + SUPER + F11").stdout)
    assert not failed["valid"] and failed["conflicts"][0]["other"] == "QA external binding"
    run("forynarch-shortcut-config", "set", files_id, "CTRL + SUPER + F12")
    assert any(c["description"] == "Files" and c["key"].upper() == "F12" for c in query("binds"))
    assert any(c["description"] == "QA external binding" for c in query("binds"))
    run("hyprctl", "reload")
    assert any(c["description"] == "Files" and c["key"].upper() == "F12" for c in query("binds"))
    assert not run("hyprctl", "configerrors").stdout.strip()
    run("forynarch-shortcut-config", "set", files_id, "")
    assert not any(c["description"] == "Files" and c["key"].upper() == "F12" for c in query("binds"))
    run("forynarch-shortcut-config", "reset", files_id)
    assert any(c["description"] == "Files" and c["key"].upper() == "E" for c in query("binds"))
    print("PASS: managed/external collision rejection, immediate remap, disable and reset")
    action("close", second)
    wait(lambda: client(second) is None)
    print("PASS: normal application close")
finally:
    if files_id:
        run("forynarch-shortcut-config", "reset", files_id, check=False)
    run("hyprctl", "reload", check=False)
    for address in owned:
        if client(address):
            action("close", address)
    run("forynarch-window-mode", "hybrid", check=False)
    run("hyprctl", "dispatch", 'hl.dsp.focus({workspace=' + str(original_workspace) + '})', check=False)
