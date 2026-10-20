"""Minimize and restore owned floating fixtures on an empty disposable workspace."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import time

assert os.getuid() == 1000
assert os.environ.get('FORYNARCH_QA_PRODUCT_UUID') == 'e299bc66-1045-ef4e-95c5-8fb979457c6c'
api = runpy.run_path('/usr/local/bin/forynarch-window-control', run_name='support')
query, dispatch, hypr = (api[key] for key in ('query', 'dispatch', 'hypr'))
workspace = 9782
assert not any(c['workspace']['id'] == workspace for c in query('clients'))
previous = query('activeworkspace')['id']
children = []
try:
    hypr('dispatch', 'hl.dsp.focus({workspace=9782})')
    for index in range(2):
        child = subprocess.Popen(['alacritty', '--class', 'ForynarchMinimizeQA', '--title', f'Minimize fixture {index}', '-e', '/usr/bin/sleep', '300'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, env={**os.environ, 'LIBGL_ALWAYS_SOFTWARE': '1'})
        children.append(child)
        for _ in range(100):
            if child.poll() is not None:
                raise AssertionError(child.stderr.read())
            if any(c.get('pid') == child.pid for c in query('clients')):
                break
            time.sleep(.1)
    fixtures = [c for c in query('clients') if c.get('pid') in {p.pid for p in children}]
    assert len(fixtures) == 2
    for c in fixtures:
        dispatch('float', c['address'], action='on')
    address = fixtures[-1]['address']
    subprocess.run(['forynarch-window-control', 'activate', address], check=True)
    time.sleep(.3)
    before = next(c for c in query('clients') if c['address'] == address)
    subprocess.run(['forynarch-window-control', 'minimize', address], check=True)
    time.sleep(.5)
    minimized = next(c for c in query('clients') if c['address'] == address)
    assert minimized['workspace']['name'] == 'special:forynarch-minimized'
    subprocess.run(['forynarch-window-switcher', 'reset'], check=True)
    subprocess.run(['forynarch-window-switcher', 'next'], check=True)
    time.sleep(.5)
    restored = next(c for c in query('clients') if c['address'] == address)
    assert restored['workspace']['id'] == workspace
    assert restored['floating'] and restored['size'] == before['size']
    assert query('activewindow')['address'] == address
    subprocess.run(['forynarch-window-switcher', 'reset'], check=True)
    subprocess.run(['forynarch-window-control', 'minimize', address], check=True)
    time.sleep(.3)
    subprocess.run(['forynarch-window-control', 'activate', address], check=True)
    time.sleep(.4)
    assert query('activewindow')['address'] == address
    assert next(c for c in query('clients') if c['address'] == address)['workspace']['id'] == workspace
    print('FLOATING_MINIMIZE_ALT_TAB_AND_HOTBAR_ACTIVATION_RESTORE_OK')
finally:
    for child in children:
        if child.poll() is None:
            child.terminate()
    subprocess.run(['forynarch-window-switcher', 'reset'], check=False)
    hypr('dispatch', f'hl.dsp.focus({{workspace={previous}}})')
