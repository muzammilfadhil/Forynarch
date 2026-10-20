"""Exercise native shared resizing on a disposable, otherwise empty QA workspace."""
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
workspace = 9781
assert not any(c['workspace']['id'] == workspace for c in query('clients'))
previous = query('activeworkspace')['id']
children, addresses = [], []
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))
preference_paths = [config/'forynarch/window-modes.json', config/'forynarch/window-sizes.json', config/'hypr/workspace-modes.lua', config/'forynarch/system.json', config/'hypr/system-settings.lua']
preferences = {p: p.read_bytes() if p.exists() else None for p in preference_paths}


def settle():
    time.sleep(.65)


def rows():
    return {c['address']: c for c in query('clients')}


def arrange(action, *windows):
    subprocess.run(['forynarch-window-layout', action, *windows], check=True)
    settle()


def assert_inside(client):
    monitor = next(m for m in query('monitors') if m['id'] == client['monitor'])
    width, height = monitor['width'], monitor['height']
    if monitor.get('transform', 0) % 2:
        width, height = height, width
    left, top, right, bottom = monitor['reserved']
    x, y = client['at']; w, h = client['size']
    assert x >= monitor['x'] + left - 1 and y >= monitor['y'] + top - 1
    assert x+w <= monitor['x'] + width/monitor['scale'] - right + 1
    assert y+h <= monitor['y'] + height/monitor['scale'] - bottom + 1


try:
    hypr('dispatch', 'hl.dsp.focus({workspace=9781})')
    subprocess.run(['forynarch-window-mode', 'floating'], check=True)
    for index in range(3):
        child = subprocess.Popen(['alacritty', '--class', 'ForynarchSmartLayoutQA', '--title', f'Layout fixture {index}',
                                  '-e', '/usr/bin/sleep', '600'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                 text=True, env={**os.environ, 'LIBGL_ALWAYS_SOFTWARE': '1'})
        children.append(child)
        for _ in range(100):
            if child.poll() is not None:
                raise AssertionError(child.stderr.read())
            client = next((c for c in query('clients') if c['pid'] == child.pid), None)
            if client:
                break
            time.sleep(.1)
        assert client
        addresses.append(client['address'])
        dispatch('float', client['address'], action='on')
        dispatch('resize', client['address'], x=400, y=300)
        dispatch('move', client['address'], x=100+index*50, y=100+index*40)
    settle()
    original = rows()
    a, b, c = addresses
    for region in ('top', 'left', 'right', 'bottom', 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'third-left', 'third-middle', 'third-right'):
        before = rows()
        arrange('snap-'+region, a)
        placed = rows()
        assert placed[a]['floating'], 'Floating snap converted a window into a tile'
        assert_inside(placed[a])
        for other in (b,c):
            for key in ('at','size','floating','workspace','fullscreen'):
                assert placed[other][key] == before[other][key], 'Single snap changed an unselected window: '+key
        dispatch('resize', a, x=-30, y=-30, relative=True); settle()
        assert all(rows()[other]['size'] == placed[other]['size'] for other in (b,c)), 'Floating resize changed a neighbor'
        dispatch('move', a, x=80, y=120); settle()
        assert rows()[a]['floating'], 'Moving a snapped float changed its mode'
        print('SINGLE_WINDOW_SNAP_LEAVES_OTHER_APPS_UNCHANGED_OK '+region, flush=True)
        arrange('restore')
    arrange('left', a)
    first = rows()[a]
    arrange('right', b)
    assert rows()[a]['floating'] and rows()[b]['floating']
    assert rows()[a]['at'] == first['at'] and rows()[a]['size'] == first['size'], 'Complementary placement automatically paired windows'
    print('COMPLEMENTARY_POSITIONS_DO_NOT_AUTO_PAIR_OK',flush=True)
    arrange('restore')
    for action in ('pair-horizontal', 'pair-vertical'):
        before = rows()[c]
        arrange(action, a, b)
        placed = rows()
        assert placed[a]['floating'] and placed[b]['floating']
        assert placed[c]['workspace']['id'] == workspace and placed[c]['at'] == before['at'] and placed[c]['size'] == before['size']
        if action == 'pair-vertical':
            assert placed[a]['at'][1]+placed[a]['size'][1] <= placed[b]['at'][1]
        print('FREE_FLOATING_PAIR_NO_HIDDEN_WINDOWS_OK '+action, flush=True)
        arrange('restore')
    subprocess.run(['forynarch-window-mode','dwindle'], check=True, stdout=subprocess.DEVNULL)
    for region in ('top', 'left', 'right', 'bottom', 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'third-left', 'third-middle', 'third-right'):
        for address in addresses:
            dispatch('float', address, action='off')
        settle()
        arrange('snap-'+region, a)
        placed = rows()
        assert json.loads(subprocess.check_output(['forynarch-window-mode','status'],text=True))['mode']=='dwindle', 'Smart snap changed the workspace preference'
        for index, address in enumerate(addresses):
            assert not placed[address]['floating'] and placed[address]['workspace']['id'] == workspace, 'Smart snap hid or left a floating participant'
            assert_inside(placed[address])
            x, y = placed[address]['at']; w, h = placed[address]['size']
            for other in addresses[index+1:]:
                ox, oy = placed[other]['at']; ow, oh = placed[other]['size']
                assert x+w <= ox or ox+ow <= x or y+h <= oy or oy+oh <= y, 'Smart snap participants overlap'
        monitor = next(m for m in query('monitors') if m['id'] == placed[a]['monitor'])
        center_x = monitor['x']+monitor['width']/monitor['scale']/2
        center_y = monitor['y']+monitor['height']/monitor['scale']/2
        x, y = placed[a]['at']; w, h = placed[a]['size']
        if region.endswith('left'): assert x+w <= center_x+2
        if region.endswith('right'): assert x >= center_x-2
        if region.startswith('top'): assert y+h <= center_y+monitor['reserved'][1]/2+2
        if region.startswith('bottom'): assert y >= center_y-2
        if region == 'third-middle':
            assert x >= monitor['x']+monitor['width']/monitor['scale']/3-2
            assert x+w <= monitor['x']+monitor['width']/monitor['scale']*2/3+2
        if region == 'top':
            dispatch('resize', a, x=0, y=60, relative=True);settle()
            resized = rows()
            assert resized[a]['size'][1] > placed[a]['size'][1]+15
            assert any(resized[other]['size'] != placed[other]['size'] for other in (b,c)), 'Other layout cells did not resize'
        print('NATIVE_SMART_SNAP_VISIBLE_SHARED_TREE_OK '+region, flush=True)
        arrange('restore')
    arrange('tile-workspace')
    for key in ('windowGap','screenMargin','cornerRadius'):
        subprocess.run(['forynarch-system','set',key,'0'],check=True,stdout=subprocess.DEVNULL)
    settle()
    zero = rows()
    monitor = next(m for m in query('monitors') if m['id'] == zero[a]['monitor'])
    assert min(zero[address]['at'][0] for address in addresses) <= monitor['x']+1
    assert min(zero[address]['at'][1] for address in addresses) <= monitor['y']+monitor['reserved'][1]+1
    assert max(zero[address]['at'][0]+zero[address]['size'][0] for address in addresses) >= monitor['x']+monitor['width']/monitor['scale']-1
    assert json.loads(hypr('-j','getoption','decoration:rounding'))['int'] == 0
    hypr('reload');settle()
    assert json.loads(hypr('-j','getoption','decoration:rounding'))['int'] == 0
    for key, value in (('windowGap',6),('screenMargin',14),('cornerRadius',28)):
        subprocess.run(['forynarch-system','set',key,str(value)],check=True,stdout=subprocess.DEVNULL)
    settle()
    assert json.loads(hypr('-j','getoption','decoration:rounding'))['int'] == 28
    assert all(rows()[address]['at'] != zero[address]['at'] or rows()[address]['size'] != zero[address]['size'] for address in addresses)
    assert 'rounding=14' not in (config/'hypr/workspace-modes.lua').read_text()
    print('NATIVE_ZERO_GAP_SQUARE_CORNERS_LIVE_REFLOW_AND_RELOAD_PERSISTENCE_OK',flush=True)
    arrange('restore')
    for action, axis in (('pair-horizontal',0), ('pair-vertical',1)):
        for address in addresses:
            dispatch('float', address, action='off')
        settle()
        arrange(action, a, b)
        before = rows()
        assert all(not before[address]['floating'] and before[address]['workspace']['id'] == workspace for address in addresses)
        dispatch('resize', a, x=70 if axis==0 else 0, y=70 if axis==1 else 0, relative=True)
        settle()
        pair = rows()
        assert pair[a]['size'][axis] > before[a]['size'][axis]+15
        assert any(pair[other]['size'] != before[other]['size'] for other in (b,c))
        for address in addresses:
            assert_inside(pair[address])
        print('NATIVE_PAIR_SHARED_RESIZE_NO_MINIMIZATION_OK '+action, flush=True)
        arrange('restore')
    arrange('tile-workspace')
    tiled = rows()
    for index, address in enumerate(addresses):
        assert not tiled[address]['floating']
        assert_inside(tiled[address])
        x, y = tiled[address]['at']; w, h = tiled[address]['size']
        for other in addresses[index+1:]:
            ox, oy = tiled[other]['at']; ow, oh = tiled[other]['size']
            assert x+w <= ox or ox+ow <= x or y+h <= oy or oy+oh <= y, 'Tiled windows overlap'
    arrange('restore')
    hypr('dispatch', 'hl.dsp.focus({window='+json.dumps('address:'+a)+'})')
    subprocess.run(['forynarch-window-control', 'activate', b], check=True)
    assert query('activewindow')['address'] == b
    assert query('clients')
    print('NATIVE_TILE_ALL_NONOVERLAP_RESTORE_AND_FLOAT_ACTIVATION_OK', flush=True)
finally:
    current = rows()
    for address in addresses:
        if address in current:
            dispatch('close', address)
    for child in children:
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.terminate(); child.wait(timeout=5)
    (Path(os.environ['XDG_RUNTIME_DIR'])/'forynarch-windows'/f'layout-{workspace}.json').unlink(missing_ok=True)
    for path, content in preferences.items():
        if content is None: path.unlink(missing_ok=True)
        else: path.write_bytes(content)
    hypr('reload')
    hypr('dispatch', 'hl.dsp.focus({workspace='+str(previous)+'})')
