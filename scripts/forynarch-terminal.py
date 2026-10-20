#!/usr/bin/env python3
"""Open the default terminal in the pointed or focused shell's local directory."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

SHELLS = {"sh", "bash", "zsh", "fish", "dash", "ksh", "nu", "elvish", "tcsh", "csh", "yash"}


def query(name):
    return json.loads(subprocess.run(["hyprctl", "-j", name], check=True,
                                    capture_output=True, text=True, timeout=2).stdout)


def terminal(client):
    return client.get("class", "").lower() in {"alacritty", "kitty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "org.kde.konsole"}


def pointed_client(clients, monitors, cursor):
    visible = {m.get("activeWorkspace", {}).get("id") for m in monitors}
    visible.update(m.get("specialWorkspace", {}).get("id") for m in monitors)
    hits = []
    for client in clients:
        if not client.get("mapped", True) or client.get("hidden", False):
            continue
        if not client.get("pinned", False) and client.get("workspace", {}).get("id") not in visible:
            continue
        x, y = client.get("at", [0, 0])
        w, h = client.get("size", [0, 0])
        if x <= cursor["x"] < x + w and y <= cursor["y"] < y + h:
            hits.append(client)
    return min(hits, key=lambda c: (-bool(c.get("fullscreen", 0)),
                                   -bool(c.get("floating", False)), c.get("focusHistoryID", 999999)), default={})


def process(pid, proc=Path("/proc"), uid=None):
    uid = os.getuid() if uid is None else uid
    directory = proc / str(pid)
    if directory.stat().st_uid != uid:
        raise ValueError("Foreign process")
    fields = (directory / "stat").read_text().rsplit(") ", 1)[1].split()
    return {"pid": pid, "ppid": int(fields[1]), "pgrp": int(fields[2]),
            "tty": int(fields[4]), "foreground": int(fields[5]), "start": fields[19],
            "exe": (directory / "exe").resolve(strict=True).name}


def shell_directory(pid, proc=Path("/proc"), uid=None):
    try:
        root = process(pid, proc, uid)
        if root["exe"] not in {"alacritty", "kitty", "wezterm-gui", "ghostty", "konsole"}:
            return None
        nodes = {pid: root}
        pending = [(pid, 0)]
        while pending:
            current, depth = pending.pop(0)
            if depth >= 16:
                return None
            children = (proc / str(current) / "task" / str(current) / "children").read_text().split()
            for child in children:
                child = int(child)
                if child in nodes:
                    continue
                if len(nodes) >= 128:
                    return None
                try:
                    node = process(child, proc, uid)
                    if node["ppid"] != current:
                        continue
                    nodes[child] = node
                    pending.append((child, depth + 1))
                except (OSError, ValueError, IndexError):
                    continue
        terminals = {node["tty"] for node in nodes.values() if node["tty"] and node["pid"] != pid}
        if len(terminals) != 1:
            return None
        for node in nodes.values():
            if not node["tty"] or node["pgrp"] != node["foreground"]:
                continue
            current = node
            while current["pid"] != pid:
                if current["exe"] in SHELLS:
                    directory = (proc / str(current["pid"]) / "cwd").resolve(strict=True)
                    latest = process(current["pid"], proc, uid)
                    if latest["start"] != current["start"] or process(pid, proc, uid)["start"] != root["start"]:
                        return None
                    return directory if directory.is_dir() and os.access(directory, os.X_OK) else None
                current = nodes.get(current["ppid"])
                if current is None:
                    break
    except (OSError, ValueError, IndexError, KeyError):
        pass
    return None


def main(argv=None):
    from forynarch_defaults import terminal_command
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--working-directory")
    parser.add_argument("--title")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    directory = Path(args.working_directory).expanduser().resolve(strict=True) if args.working_directory else None
    try:
        active = query("activewindow")
        pointed = pointed_client(query("clients"), query("monitors"), query("cursorpos"))
        for client in (() if directory is not None else (pointed, active)):
            if terminal(client):
                directory = shell_directory(int(client.get("pid", 0)))
                if directory is not None:
                    break
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        pass
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if directory is not None and not directory.is_dir():
        raise ValueError("The working directory is not a directory.")
    launch = terminal_command(directory or Path.home(), command, args.title)
    try:
        if "virtualbox" in Path("/sys/class/dmi/id/product_name").read_text().lower():
            os.environ.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
    except OSError:
        pass
    os.execvp(launch[0], launch)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError):
        sys.exit("The terminal could not be started.")
