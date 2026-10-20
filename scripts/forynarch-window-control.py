#!/usr/bin/env python3
"""Scoped window actions and recoverable minimization; no background process."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from forynarch_app_identity import identity as application_identity


def hypr(*args):
    result = subprocess.run(["hyprctl", *args], text=True, capture_output=True, timeout=5, check=True)
    if args[0] == "dispatch" and not result.stdout.strip().startswith("ok"):
        raise ValueError("The compositor could not apply that window action.")
    return result.stdout


def query(name):
    return json.loads(hypr("-j", name))


def dispatch(name, address, **arguments):
    arguments["window"] = "address:" + address
    values = ",".join(key + "=" + json.dumps(value) for key, value in arguments.items())
    hypr("dispatch", "hl.dsp.window." + name + "({" + values + "})")


def save(path, value):
    fd, temporary = tempfile.mkstemp(prefix=".window-state-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if not os.environ.get("XDG_RUNTIME_DIR"):
        raise ValueError("A desktop session is required.")
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "forynarch-windows"
    directory.mkdir(mode=0o700, exist_ok=True)
    state_file = directory / "minimized.json"
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action not in {"status", "activate", "minimize", "restore", "restore-last", "maximize", "fullscreen", "close", "toggle-all", "show-desktop"}:
        raise ValueError("Unknown window action.")
    if len(sys.argv) > 3 or (action in {"status", "toggle-all", "restore-last", "show-desktop"} and len(sys.argv) > 2):
        raise ValueError("Invalid window action arguments.")
    if action == "toggle-all":
        return toggle_all(directory)
    with open(directory / "lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        clients = query("clients")
        workspace = query("activeworkspace")["id"]
        active = query("activewindow").get("address", "")
        by_address = {client["address"]: client for client in clients}
        state = json.loads(state_file.read_text()) if state_file.exists() else {}
        state = {address: value for address, value in state.items()
                 if address in by_address and by_address[address]["pid"] == value.get("pid")
                 and by_address[address]["workspace"]["name"] == "special:forynarch-minimized"}
        if action == "show-desktop":
            return show_desktop(directory, state_file, state, by_address, workspace, active)
        if action == "status":
            rows = []
            for client in clients:
                address = client["address"]
                minimized = state.get(address, {}).get("workspace") == workspace
                if not minimized and (client["workspace"]["id"] != workspace or not client.get("mapped") or client.get("hidden")):
                    continue
                rows.append({"address": address, "pid": client["pid"], "title": client.get("title", "")[:120],
                             "app": client.get("class", ""), "minimized": minimized,
                             "fullscreen": client.get("fullscreen", 0), "floating": client.get("floating", False),
                             "at": client.get("at", [0, 0]), "size": client.get("size", [0, 0]),
                             "monitor": client.get("monitor", 0)})
                if client.get("class", "").lower() in {"thunar", "org.xfce.thunar"}:
                    title = re.sub(r" - Thunar$", "", rows[-1]["title"])
                    rows[-1]["title"] = (title + " · " if title else "") + "File Manager"
                    rows[-1]["app"] = "File Manager"
                rows[-1].update(application_identity(client))
            save(state_file, state)
            desktop_file = directory / f"desktop-{workspace}.json"
            desktop = json.loads(desktop_file.read_text()) if desktop_file.exists() else {}
            shown = any(row.get("address") in state and row.get("pid") == state[row["address"]].get("pid")
                        and state[row["address"]].get("workspace") == workspace
                        for row in desktop.get("windows", []))
            print(json.dumps({"active": active, "workspace": workspace, "windows": rows, "desktopShown": shown}))
            return 0
        if action == "restore-last":
            candidates = [address for address, value in state.items() if value["workspace"] == workspace]
            if not candidates:
                raise ValueError("There are no minimized windows on this workspace.")
            address = candidates[-1]
            action = "restore"
        else:
            address = sys.argv[2] if len(sys.argv) == 3 else active
        if not re.fullmatch(r"0x[0-9a-fA-F]+", address) or address not in by_address:
            raise ValueError("Select an open application first.")
        client = by_address[address]
        minimized = state.get(address)
        if (minimized and minimized["workspace"] != workspace) or (not minimized and client["workspace"]["id"] != workspace):
            raise ValueError("That window is on a different workspace. Select it there.")
        if action == "minimize":
            if not minimized:
                state[address] = {"pid": client["pid"], "workspace": workspace}
                dispatch("move", address, workspace="special:forynarch-minimized", follow=False)
        else:
            if minimized:
                dispatch("move", address, workspace=minimized["workspace"], follow=False)
                state.pop(address, None)
            if action in {"activate", "restore"}:
                hypr("dispatch", "hl.dsp.focus({window=" + json.dumps("address:" + address) + "})")
                if client.get("floating"):
                    dispatch("alter_zorder", address, mode="top")
            elif action == "close":
                dispatch("close", address)
            else:
                target = 1 if action == "maximize" else 2
                dispatch("fullscreen", address, mode="maximized" if action == "maximize" else "fullscreen",
                         action="unset" if client.get("fullscreen") == target else "set",
                         **({"layout_aware":False} if action=="maximize" else {}))
        save(state_file, state)
    return 0


def show_desktop(directory, state_file, state, clients, workspace, active):
    if not isinstance(workspace, int) or workspace < 1:
        raise ValueError("Select a normal workspace first.")
    path = directory / f"desktop-{workspace}.json"
    snapshot = json.loads(path.read_text()) if path.exists() else {}
    restore = [row for row in snapshot.get("windows", []) if row.get("address") in state
               and state[row["address"]].get("pid") == row.get("pid")
               and state[row["address"]].get("workspace") == workspace]
    if restore:
        for row in restore:
            address = row["address"]
            dispatch("move", address, workspace=workspace, follow=False)
            state.pop(address, None)
            save(state_file, state)
        path.unlink(missing_ok=True)
        original = snapshot.get("active")
        if original in {row["address"] for row in restore}:
            hypr("dispatch", "hl.dsp.focus({window=" + json.dumps("address:" + original) + "})")
            if clients[original].get("floating"):
                dispatch("alter_zorder", original, mode="top")
        return 0
    windows = [client for client in clients.values() if client["workspace"]["id"] == workspace
               and client.get("mapped") and not client.get("hidden") and not client.get("pinned")]
    if not windows:
        path.unlink(missing_ok=True)
        return 0
    snapshot = {"workspace": workspace, "active": active,
                "windows": [{"address": client["address"], "pid": client["pid"]} for client in windows]}
    for client in windows:
        state[client["address"]] = {"pid": client["pid"], "workspace": workspace}
    save(state_file, state)
    save(path, snapshot)
    for client in windows:
        dispatch("move", client["address"], workspace="special:forynarch-minimized", follow=False)
    return 0


def toggle_all(directory):
    with open(directory / "workspace-lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        workspace = query("activeworkspace")["id"]
        if not isinstance(workspace, int) or workspace < 1:
            raise ValueError("Select a normal workspace first.")
        settings = json.loads(subprocess.check_output(["forynarch-window-mode", "status"], text=True))
        current = settings["mode"]
        path = directory / ("workspace-" + str(workspace) + ".json")
        snapshot = json.loads(path.read_text()) if path.exists() else None
        if current != "floating":
            clients = [c for c in query("clients") if c["workspace"]["id"] == workspace]
            save(path, {"mode": current, "windows": [{"address": c["address"], "pid": c["pid"], "floating": c["floating"]} for c in clients]})
            subprocess.run(["forynarch-window-mode", "floating", "--apply-open"], check=True)
            monitors = {m["id"]: m for m in query("monitors")}
            ratio = {"compact": .60, "comfortable": .72, "spacious": .86}.get(settings.get("size"), .72)
            for index, client in enumerate(clients):
                if client["floating"] or client.get("fullscreen"):
                    continue
                monitor = monitors.get(client["monitor"])
                if not monitor:
                    continue
                pixels = [monitor["width"], monitor["height"]]
                if monitor.get("transform", 0) % 2:
                    pixels.reverse()
                left, top, right, bottom = monitor.get("reserved", [0, 0, 0, 0])
                width = pixels[0] / monitor["scale"] - left - right
                height = pixels[1] / monitor["scale"] - top - bottom
                size = [max(1, int(width * ratio)), max(1, int(height * ratio))]
                offset = (index % 5 - 2) * 22
                x = monitor["x"] + left + max(0, min(width - size[0], (width - size[0]) / 2 + offset))
                y = monitor["y"] + top + max(0, min(height - size[1], (height - size[1]) / 2 + offset))
                dispatch("resize", client["address"], x=size[0], y=size[1])
                dispatch("move", client["address"], x=int(x), y=int(y))
        else:
            mode = snapshot["mode"] if snapshot else "hybrid"
            if mode not in {"hybrid", "dwindle", "master", "scrolling"}:
                mode = "hybrid"
            subprocess.run(["forynarch-window-mode", mode, "--apply-open"], check=True)
            clients = {c["address"]: c for c in query("clients") if c["workspace"]["id"] == workspace}
            for previous in snapshot.get("windows", []) if snapshot else []:
                client = clients.get(previous["address"])
                if client and client["pid"] == previous["pid"] and client["floating"] != previous["floating"]:
                    dispatch("float", previous["address"], action="on" if previous["floating"] else "off")
            path.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(str(error) if isinstance(error, ValueError) else "The window action could not complete. Try selecting the application again.", file=sys.stderr)
        sys.exit(1)
