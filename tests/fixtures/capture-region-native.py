"""Region selection and cancellation with host pointer input in disposable QA."""
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import time

assert os.getuid() == 1000
assert os.environ.get('FORYNARCH_QA_PRODUCT_UUID') == 'e299bc66-1045-ef4e-95c5-8fb979457c6c'
with tempfile.TemporaryDirectory(prefix='forynarch-region-qa-') as temporary:
    base = Path(temporary)
    env = {**os.environ, 'XDG_CONFIG_HOME': str(base/'config'), 'XDG_STATE_HOME': str(base/'state')}
    subprocess.run(['forynarch-capture', 'set', 'directory', str(base/'shots')], env=env, check=True, stdout=subprocess.DEVNULL)
    selection = subprocess.Popen(['forynarch-capture', 'region'], env=env, stdout=subprocess.PIPE, text=True)
    Path('/tmp/capture-region-phase').write_text('select')
    result = json.loads(selection.communicate(timeout=60)[0])
    png = Path(result['saved']).read_bytes()
    width, height = struct.unpack('>II', png[16:24])
    assert 319 <= width <= 321 and 219 <= height <= 221, (width, height)
    assert hashlib.sha256(subprocess.check_output(['wl-paste', '--type', 'image/png'])).digest() == hashlib.sha256(png).digest()
    previous = sorted((base/'shots').iterdir())
    cancellation = subprocess.Popen(['forynarch-capture', 'region'], env=env, stdout=subprocess.PIPE, text=True)
    Path('/tmp/capture-region-phase').write_text('cancel')
    assert json.loads(cancellation.communicate(timeout=60)[0]) == {'cancelled': True}
    assert sorted((base/'shots').iterdir()) == previous
    assert hashlib.sha256(subprocess.check_output(['wl-paste', '--type', 'image/png'])).digest() == hashlib.sha256(png).digest()
    Path('/tmp/capture-region-phase').write_text('passed')
    print(f'NATIVE_REGION_{width}x{height}_CLIPBOARD_AND_CANCEL_NO_CHANGE_OK')
