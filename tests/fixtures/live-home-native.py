"""Read-only acceptance check for the disposable Archiso desktop account."""
import os
from pathlib import Path
import pwd
import subprocess

assert Path('/run/archiso').is_dir(), 'Live-only fixture'
assert os.environ.get('FORYNARCH_QA_PRODUCT_UUID') == Path('/sys/class/dmi/id/product_uuid').read_text().strip(), 'Explicit QA VM identity required'
account = pwd.getpwnam('liveuser')
home = Path(account.pw_dir)
assert account.pw_uid == 1000 and home == Path('/home/liveuser')
assert not home.is_symlink() and home.stat().st_uid == account.pw_uid
subprocess.run(['runuser', '-u', 'liveuser', '--', 'test', '-w', str(home)], check=True)
for relative in ('.config/hypr/hyprland.lua', '.config/quickshell/forynarch/shell.qml', '.config/mako/config'):
    item = home / relative
    assert item.is_file() and item.stat().st_uid == account.pw_uid, relative
    subprocess.run(['runuser', '-u', 'liveuser', '--', 'test', '-r', str(item)], check=True)
assert (home / '.local/share/sddm').is_dir()
print('NATIVE_LIVE_HOME_OWNERSHIP_WRITABILITY_AND_DESKTOP_CONFIG_OK')
