#!/usr/bin/env python3
"""Check compositor surfaces while changing real widget settings in the QA VM."""
import json
import math
import os
from pathlib import Path
import subprocess
import time

assert os.getuid() == 1000
expected_uuid = os.environ.get('FORYNARCH_QA_PRODUCT_UUID', '')
assert expected_uuid and Path('/sys/class/dmi/id/product_uuid').read_text().strip() == expected_uuid

def call(*args):
    return subprocess.check_output(args, text=True, timeout=15)

def ipc(method, *args):
    return call("qs", "-c", "forynarch", "ipc", "call", "appearance", method, *map(str, args))

before = json.loads(ipc("mediaStatus"))
monitor = json.loads(call("hyprctl", "-j", "monitors"))[0]
ipc("editWidgets")
try:
    for key in ("clock", "calendar", "greeting", "media"):
        ipc("setWidget", key, "true")
    for style in ("classic", "macshell"):
        ipc("setMusic", "musicStyle", style)
        for lyrics in (True, False):
            ipc("setMusic", "musicLyrics", str(lyrics).lower())
            for percent in (80, 100, 120):
                ipc("setWidgetScale", percent)
                time.sleep(.35)
                all_layers = json.loads(call("hyprctl", "-j", "layers"))
                widgets = [item for output in all_layers.values() for level in output["levels"].values()
                           for item in level if item["namespace"] == "forynarch-widgets"]
                scale = percent / 100
                expected = sorted(math.ceil(height * scale) for height in
                                  (224, 130, 94, (190 if style == "macshell" else 246) if lyrics else 130))
                assert sorted(item["h"] for item in widgets) == expected, (style, lyrics, percent, widgets)
                for item in widgets:
                    assert item["w"] == math.ceil(224 * scale), item
                    assert 0 <= item["x"] <= monitor["width"] - item["w"], item
                    assert 0 <= item["y"] <= monitor["height"] - item["h"], item
    print("PASS widget surfaces: 12 style/lyrics/scale combinations; correct content heights, widths and screen bounds")
finally:
    ipc("setMusic", "musicStyle", before["musicStyle"])
    ipc("setMusic", "musicLyrics", str(before["lyrics"]).lower())
    ipc("finishWidgets", "false")
