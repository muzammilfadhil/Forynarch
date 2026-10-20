#!/usr/bin/env python3
"""On-demand free floating placement and native shared window layouts."""
import fcntl
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys

support = Path(__file__).with_name("forynarch-window-control")
if not support.exists():
    support = support.with_suffix(".py")
api = runpy.run_path(str(support), run_name="forynarch_window_support")
query, dispatch, hypr, save = (api[name] for name in ("query", "dispatch", "hypr", "save"))
REGIONS = {
    "left": (0, 0, .5, 1), "right": (.5, 0, .5, 1),
    "top": (0, 0, 1, .5), "bottom": (0, .5, 1, .5),
    "top-left": (0, 0, .5, .5), "top-right": (.5, 0, .5, .5),
    "bottom-left": (0, .5, .5, .5), "bottom-right": (.5, .5, .5, .5),
    "third-left": (0, 0, 1 / 3, 1), "third-middle": (1 / 3, 0, 1 / 3, 1),
    "third-right": (2 / 3, 0, 1 / 3, 1),
}
SMART_REGIONS = set(REGIONS)


def layout_style():
    path = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config"))) / "forynarch/system.json"
    prefs = json.loads(path.read_text()) if path.exists() else {}
    style = {"windowGap": prefs.get("windowGap", 6), "screenMargin": prefs.get("screenMargin", 14)}
    for key, limit in (("windowGap", 40), ("screenMargin", 64)):
        if type(style[key]) is not int or not 0 <= style[key] <= limit:
            raise ValueError("Window spacing settings are invalid.")
    return style


def region_box(monitor, region, style=None):
    width, height = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    left, top, right, bottom = monitor.get("reserved", [0, 0, 0, 0])
    width = width / monitor["scale"] - left - right
    height = height / monitor["scale"] - top - bottom
    if width < 160 or height < 160:
        raise ValueError("The display has too little usable space for this layout.")
    x, y, w, h = REGIONS[region] if isinstance(region, str) else region
    if style is not None:
        inside, outside = style["windowGap"], style["screenMargin"]
        padding = [outside if edge else inside for edge in (x == 0, y == 0, x+w >= 1, y+h >= 1)]
        return (round(monitor["x"]+left+x*width+padding[0]+1),
                round(monitor["y"]+top+y*height+padding[1]+1),
                max(1, round(w*width)-padding[0]-padding[2]-2),
                max(1, round(h*height)-padding[1]-padding[3]-2))
    # Keep borders inside the work area and leave an 8-pixel shared gap.
    return (round(monitor["x"] + left + x * width + 4),
            round(monitor["y"] + top + y * height + 4),
            max(1, round(w * width) - 8), max(1, round(h * height) - 8))


def focus(address):
    hypr("dispatch", "hl.dsp.focus({window=" + json.dumps("address:" + address) + "})")
    client = next((c for c in query("clients") if c["address"] == address), {})
    if client.get("floating"):
        dispatch("alter_zorder", address, mode="top")


def unmaximize(client):
    if client.get("fullscreen"):
        dispatch("fullscreen", client["address"], mode="fullscreen", action="unset")
        dispatch("fullscreen", client["address"], mode="maximized", action="unset")


def floating_preference(workspace):
    path = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config"))) / "forynarch/window-modes.json"
    return (json.loads(path.read_text()) if path.exists() else {}).get(str(workspace)) in {"floating", "hybrid"}


def floating_cells(region, count):
    """Partition only the remaining space; each result stays an independent float."""
    x, y, w, h = REGIONS[region]
    cells = []
    if x > 0:
        cells.append((0, 0, x, 1))
    if x+w < 1:
        cells.append((x+w, 0, 1-x-w, 1))
    if y > 0:
        cells.append((x, 0, w, y))
    if y+h < 1:
        cells.append((x, y+h, w, 1-y-h))
    if count == 0:
        return []
    while len(cells) < count:
        index = max(range(len(cells)), key=lambda i: cells[i][2]*cells[i][3])
        cx, cy, cw, ch = cells.pop(index)
        if cw >= ch:
            cells.extend([(cx, cy, cw/2, ch), (cx+cw/2, cy, cw/2, ch)])
        else:
            cells.extend([(cx, cy, cw, ch/2), (cx, cy+ch/2, cw, ch/2)])
    return sorted(cells, key=lambda cell: (-cell[2]*cell[3], cell[1], cell[0]))[:count]


def floating_snap(region, dragged, participants, monitor):
    others = [c for c in participants if c["address"] != dragged["address"]]
    cells = [REGIONS[region], *floating_cells(region, len(others))]
    style = layout_style()
    for client, cell in zip([dragged, *others], cells):
        x, y, width, height = region_box(monitor, cell, style)
        unmaximize(client)
        dispatch("float", client["address"], action="on")
        dispatch("resize", client["address"], x=width, y=height)
        dispatch("move", client["address"], x=x, y=y)
    focus(dragged["address"])


def smart_snap(region, dragged, participants, workspace, monitor):
    """Insert into a shared native tree, leaving every participant visible."""
    address = dragged["address"]
    others = [c for c in participants if c["address"] != address]
    if region == "third-middle" and len(participants) < 3:
        raise ValueError("Open at least three windows for a middle-third layout.")
    if not others:
        x, y, width, height = region_box(monitor, region, layout_style())
        unmaximize(dragged)
        dispatch("float", address, action="on")
        dispatch("resize", address, x=width, y=height)
        dispatch("move", address, x=x, y=y)
        focus(address)
        return
    corner = region in {"top-left", "top-right", "bottom-left", "bottom-right"}
    horizontal = region in {"left", "right"} or corner or region.startswith("third-")
    leading = region.endswith("left") if horizontal else region == "top"
    direction = ("l" if leading else "r") if horizontal else ("u" if leading else "d")
    hypr("eval", "hl.workspace_rule({workspace=" + json.dumps(str(workspace)) + ',layout="dwindle"})')
    for client in participants:
        unmaximize(client)
    dispatch("float", address, action="on")
    for client in others:
        if client["floating"]:
            dispatch("float", client["address"], action="off")
    focus(others[0]["address"])
    hypr("dispatch", 'hl.dsp.layout("preselect ' + direction + '")')
    dispatch("float", address, action="off")
    focus(address)
    if len(others) > 1:
        # An already-root node is a valid result, not a failed arrangement.
        result = subprocess.run(["hyprctl", "dispatch", 'hl.dsp.layout("movetoroot")'],
                                check=True, capture_output=True, text=True, timeout=5)
        if not result.stdout.strip().startswith("ok") and "can't movetoroot" not in result.stdout:
            raise ValueError("The shared layout could not be created.")
    placed = {c["address"]: c for c in query("clients")}
    currently_horizontal = abs(placed[address]["at"][0] - min(placed[c["address"]]["at"][0] for c in others)) > 20
    if currently_horizontal != horizontal:
        hypr("dispatch", 'hl.dsp.layout("togglesplit")')
    placed = {c["address"]: c for c in query("clients")}
    axis = 0 if horizontal else 1
    before = placed[address]["at"][axis] < min(placed[c["address"]]["at"][axis] for c in others)
    if before != leading:
        hypr("dispatch", 'hl.dsp.layout("swapsplit")')
    ratio = 2/3 if region in {"third-left", "third-middle"} else 4/3 if region == "third-right" else 1.0
    hypr("dispatch", 'hl.dsp.layout("splitratio ' + str(ratio) + ' exact")')
    if len(others) == 2:
        placed = {c["address"]: c for c in query("clients")}
        cells = [placed[c["address"]] for c in others]
        width = max(c["at"][0]+c["size"][0] for c in cells)-min(c["at"][0] for c in cells)
        height = max(c["at"][1]+c["size"][1] for c in cells)-min(c["at"][1] for c in cells)
        if (abs(cells[0]["at"][0]-cells[1]["at"][0]) > 20) != (width >= height):
            focus(others[0]["address"])
            hypr("dispatch", 'hl.dsp.layout("togglesplit")')
            focus(address)
    if (corner or region == "third-middle") and len(others) > 1:
        x, y, w, h = region_box(monitor, "third-right" if region == "third-middle" else region)
        companion = min(others, key=lambda c: (c["at"][0]+c["size"][0]/2-x-w/2)**2
                        + (c["at"][1]+c["size"][1]/2-y-h/2)**2)
        dispatch("float", companion["address"], action="on")
        focus(address)
        direction = "r" if region == "third-middle" else "d" if region.startswith("top") else "u"
        hypr("dispatch", 'hl.dsp.layout("preselect ' + direction + '")')
        dispatch("float", companion["address"], action="off")
        focus(address)
        hypr("dispatch", 'hl.dsp.layout("splitratio 1.0 exact")')
    focus(address)


def restore(snapshot, clients):
    scoped = set()
    if snapshot.get("minimized"):
        status = json.loads(subprocess.check_output(["forynarch-window-control", "status"], text=True))
        if status["workspace"] == snapshot["workspace"]:
            scoped = {window["address"] for window in status["windows"] if window["minimized"]}
    for previous in snapshot.get("minimized", []):
        client = next((c for c in clients if c["address"] == previous["address"] and c["pid"] == previous["pid"]), None)
        if client and client["address"] in scoped and client["workspace"].get("name") == "special:forynarch-minimized":
            subprocess.run(["forynarch-window-control", "restore", client["address"]], check=True)
    if snapshot.get("minimized"):
        clients = query("clients")
    by_address = {client["address"]: client for client in clients}
    valid = []
    for previous in snapshot["windows"]:
        client = by_address.get(previous["address"])
        if not client or client["pid"] != previous["pid"] or client["workspace"]["id"] != snapshot["workspace"]:
            continue
        valid.append(previous)
        unmaximize(client)
        dispatch("float", client["address"], action="on")
        dispatch("resize", client["address"], x=previous["size"][0], y=previous["size"][1])
        dispatch("move", client["address"], x=previous["at"][0], y=previous["at"][1])
    hypr("eval", "hl.workspace_rule({workspace=" + json.dumps(str(snapshot["workspace"]))
         + ",layout=" + json.dumps(snapshot["layout"]) + "})")
    for previous in valid:
        if not previous["floating"]:
            dispatch("float", previous["address"], action="off")
        if previous.get("fullscreen"):
            dispatch("fullscreen", previous["address"],
                     mode="maximized" if previous["fullscreen"] == 1 else "fullscreen", action="set")
    if any(previous["address"] == snapshot.get("active") for previous in valid):
        focus(snapshot["active"])


def apply(action, addresses):
    workspace = query("activeworkspace")
    if not isinstance(workspace.get("id"), int) or workspace["id"] < 1:
        raise ValueError("Select a normal workspace first.")
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "forynarch-windows"
    directory.mkdir(mode=0o700, exist_ok=True)
    with open(directory / "layout-lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = directory / ("layout-" + str(workspace["id"]) + ".json")
        clients = [c for c in query("clients") if c["workspace"]["id"] == workspace["id"] and c.get("mapped") and not c.get("hidden")]
        if action == "restore":
            if not path.exists():
                raise ValueError("There is no saved arrangement on this workspace.")
            restore(json.loads(path.read_text()), query("clients"))
            path.unlink()
            return
        by_address = {client["address"]: client for client in clients}
        if action == "tile-workspace":
            addresses = [c["address"] for c in clients if not c.get("pinned")]
            if not addresses:
                raise ValueError("There are no windows to tile on this workspace.")
        for address in addresses:
            if not re.fullmatch(r"0x[0-9a-fA-F]+", address) or address not in by_address:
                raise ValueError("Choose an open window on the current workspace.")
        selected = [by_address[address] for address in addresses]
        if len(set(addresses)) != len(addresses):
            raise ValueError("Choose two different windows.")
        if any(len(client.get("grouped", [])) > 1 for client in selected):
            raise ValueError("Ungroup these windows before arranging them.")
        if any(client.get("pinned") for client in selected):
            raise ValueError("Unpin these windows before arranging them.")
        smart_region = action[5:] if action.startswith("snap-") else None
        prior = json.loads(path.read_text()) if path.exists() else {}
        if prior.get("schema") != 2:
            prior = {}
        if any(client["monitor"] != selected[0]["monitor"] for client in selected):
            raise ValueError("Choose windows on the same display.")
        free_placement = selected[0].get("floating") or floating_preference(workspace["id"])
        monitors = {monitor["id"]: monitor for monitor in query("monitors")}
        monitor = monitors[selected[0]["monitor"]]
        touched = [c for c in clients if c in selected or
                   (not free_placement and (action.startswith("pair-") or smart_region) and c["monitor"] == selected[0]["monitor"] and not c.get("pinned"))]
        if (smart_region or (action.startswith("pair-") and not free_placement)) and any(len(c.get("grouped", [])) > 1 for c in touched):
            raise ValueError("Ungroup windows before using smart snap.")
        snapshot = {"schema": 2, "workspace": workspace["id"], "active": query("activewindow").get("address", ""),
                    "layout": workspace.get("tiledLayout", "dwindle"),
                    "windows": [{key: c[key] for key in ("address", "pid", "floating", "at", "size", "fullscreen")} for c in touched]}
        saved = prior or json.loads(json.dumps(snapshot))
        for previous in snapshot["windows"]:
            if not any(old["address"] == previous["address"] and old["pid"] == previous["pid"] for old in saved["windows"]):
                saved["windows"].append(previous)
        try:
            if smart_region:
                if free_placement:
                    floating_snap(smart_region, selected[0], selected, monitor)
                else:
                    smart_snap(smart_region, selected[0], touched, workspace["id"], monitor)
                for client in touched:
                    saved.get("regions", {}).pop(client["address"], None)
            elif action.startswith("pair-") and free_placement:
                floating_snap("left" if action == "pair-horizontal" else "top", selected[0], selected, monitor)
                for client in selected:
                    saved.get("regions", {}).pop(client["address"], None)
            elif action in REGIONS:
                client = selected[0]
                x, y, width, height = region_box(monitor, action, layout_style())
                unmaximize(client)
                dispatch("float", client["address"], action="on")
                dispatch("resize", client["address"], x=width, y=height)
                dispatch("move", client["address"], x=x, y=y)
                focus(client["address"])
                placed = next(c for c in query("clients") if c["address"] == client["address"])
                saved.setdefault("regions", {})[client["address"]] = {
                    "region": action, **{key: placed[key] for key in ("pid", "at", "size")}}
            elif action == "tile-workspace":
                hypr("eval", "hl.workspace_rule({workspace=" + json.dumps(str(workspace["id"])) + ',layout="dwindle"})')
                for client in selected:
                    unmaximize(client)
                    dispatch("float", client["address"], action="off")
                    saved.get("regions", {}).pop(client["address"], None)
                focus(snapshot["active"] if snapshot["active"] in addresses else addresses[0])
            else:
                participants = selected + [c for c in touched if c not in selected]
                smart_snap("left" if action == "pair-horizontal" else "top", selected[0], participants, workspace["id"], monitor)
                for client in touched:
                    saved.get("regions", {}).pop(client["address"], None)
            save(path, saved)
        except Exception:
            restore(snapshot, query("clients"))
            raise


def main():
    if not os.environ.get("XDG_RUNTIME_DIR"):
        raise ValueError("A desktop session is required.")
    args = sys.argv[1:]
    if not args or args[0] not in {*REGIONS, *("snap-"+region for region in SMART_REGIONS), "pair-horizontal", "pair-vertical", "restore", "tile-workspace"}:
        raise ValueError("Choose a supported window arrangement.")
    action, addresses = args[0], args[1:]
    expected = 2 if action.startswith("pair-") else 0 if action in {"restore", "tile-workspace"} else 1
    if not addresses and expected == 1:
        addresses = [query("activewindow").get("address", "")]
    if len(addresses) != expected:
        raise ValueError("Choose the windows for this arrangement.")
    apply(action, addresses)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, ValueError) else "The window arrangement could not be applied."
        print(message, file=sys.stderr)
        subprocess.run(["notify-send", "Window arrangement", message], check=False)
        sys.exit(1)
