#!/usr/bin/env python3
"""Keep the selected image and render it using the session's one swaybg process."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit
from urllib.request import url2pathname

DEFAULT = '/usr/share/backgrounds/forynarch/navy.svg'
EXTENSIONS = {'.png','.jpg','.jpeg','.webp','.bmp','.svg','.avif'}

def preferences():
    return Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'forynarch/wallpaper.json'

def chosen():
    try:
        path = Path(json.loads(preferences().read_text())['image'])
        if path.is_file():
            return str(path)
    except (OSError,ValueError,KeyError,TypeError):
        pass
    return DEFAULT

def local_image(value):
    if value.startswith('file:'):
        uri = urlsplit(value)
        if uri.netloc not in ('','localhost') or uri.query or uri.fragment:
            raise ValueError('Choose an image stored on this computer.')
        value = url2pathname(uri.path)
    elif '://' in value:
        raise ValueError('Choose an image stored on this computer.')
    path = Path(value).expanduser().resolve(strict=True)
    if not path.is_file() or path.suffix.lower() not in EXTENSIONS or not 0 < path.stat().st_size <= 64*1024**2:
        raise ValueError('Choose a supported image no larger than 64 MiB.')
    return path

def write_preferences(data):
    path = preferences();path.parent.mkdir(parents=True,exist_ok=True)
    fd,name = tempfile.mkstemp(dir=path.parent,prefix='.wallpaper-')
    try:
        with os.fdopen(fd,'w') as stream:
            json.dump(data,stream);stream.write('\n')
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

def select(value):
    source = local_image(value)
    data = source.read_bytes()
    directory = Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'forynarch/wallpapers'
    directory.mkdir(parents=True,exist_ok=True)
    image = directory/(hashlib.sha256(data).hexdigest()+source.suffix.lower())
    if not image.exists():
        fd,name = tempfile.mkstemp(dir=directory,prefix='.image-')
        try:
            with os.fdopen(fd,'wb') as stream:stream.write(data)
            os.replace(name,image)
        finally:
            if os.path.exists(name):os.unlink(name)
    previous = chosen()
    write_preferences({'image':str(image)})
    try:
        subprocess.run(['systemctl','--user','restart','forynarch-wallpaper.service'],check=True,capture_output=True,timeout=10)
        time.sleep(.25)
        subprocess.run(['systemctl','--user','is-active','--quiet','forynarch-wallpaper.service'],check=True,capture_output=True,timeout=5)
    except (subprocess.SubprocessError,OSError):
        write_preferences({'image':previous})
        subprocess.run(['systemctl','--user','restart','forynarch-wallpaper.service'],capture_output=True,timeout=10,check=False)
        raise ValueError('The image could not be displayed. The previous wallpaper was restored.') from None
    return {'image':str(image)}

def main():
    args = sys.argv[1:]
    if args == ['render']:
        os.execvp('swaybg',['swaybg','-i',chosen(),'-m','fill'])
    elif args == ['restore']:
        subprocess.run(['systemctl','--user','restart','forynarch-wallpaper.service'],check=True,timeout=10)
    elif len(args)==2 and args[0]=='set':
        print(json.dumps(select(args[1])))
    elif args == ['status']:
        print(json.dumps({'image':chosen()}))
    else:
        raise ValueError('Usage: forynarch-wallpaper set IMAGE | restore | status')

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        message=str(error)
        print(message,file=sys.stderr)
        if os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
            try:subprocess.run(['notify-send','Wallpaper',message],timeout=3,check=False)
            except (OSError,subprocess.SubprocessError):pass
        raise SystemExit(1)
