#!/usr/bin/env python3
"""Move/resize only an owned probe in the approved diskless desktop fixture."""
import json
import os
from pathlib import Path
import subprocess
import time

expected_uuid = os.environ.get('FORYNARCH_QA_PRODUCT_UUID', '')
assert expected_uuid and Path('/sys/class/dmi/id/product_uuid').read_text().strip() == expected_uuid
assert os.getuid() != 0 and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')


def hypr(*args):
    return subprocess.check_output(['hyprctl', *args], text=True, timeout=5)


def find():
    return next((w for w in json.loads(hypr('-j', 'clients')) if w['class'] == 'ForynarchRepaintFixture'), None)


original = json.loads(hypr('-j', 'getoption', 'decoration:rounding'))['int']
probe = None
try:
    hypr('eval', 'hl.window_rule({name="forynarch-repaint-fixture",match={class="^ForynarchRepaintFixture$"},float=true,size={400,240},center=true})')
    hypr('eval', 'hl.config({decoration={rounding=40}})')
    probe = subprocess.Popen(['alacritty', '--class', 'ForynarchRepaintFixture', '-e', 'sleep', '60'])
    for _ in range(40):
        window = find()
        if window:
            break
        time.sleep(.25)
    assert window is not None, 'The probe could not create a Wayland window.'
    address = window['address']
    for index in range(18):
        hypr('dispatch', 'hl.dsp.window.move({window="address:' + address + '",x=' + str(320 + index * 30) + ',y=' + str(250 + index * 20) + '})')
        time.sleep(.04)
    hypr('dispatch', 'hl.dsp.window.resize({window="address:' + address + '",x=520,y=320})')
    time.sleep(.4)
    assert find()['floating'], 'Movement changed the window mode.'
    subprocess.run(['forynarch-window-control', 'minimize', address], check=True)
    print('PASS 18 native moves, resize and minimize, rounding 40. Compare the cleared area against a full redraw externally.')
finally:
    if probe:
        probe.terminate()
    hypr('eval', 'hl.config({decoration={rounding=' + str(original) + '}})')
