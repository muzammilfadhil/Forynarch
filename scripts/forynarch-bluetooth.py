#!/usr/bin/env python3
"""Read Bluetooth service/radio health without starting discovery."""
import json
import subprocess
import sys

def status():
    service=subprocess.run(['systemctl','is-active','--quiet','bluetooth.service'],capture_output=True,timeout=3).returncode==0
    result=subprocess.run(['rfkill','--json','--output','TYPE,SOFT,HARD'],capture_output=True,text=True,timeout=3)
    if result.returncode:
        return {'serviceRunning':service,'softBlocked':False,'hardBlocked':False,'radioStatusKnown':False}
    radios=[item for item in json.loads(result.stdout).get('rfkilldevices',[]) if item.get('type')=='bluetooth']
    def blocked(value):return value in (True,1,'blocked','yes')
    return {'serviceRunning':service,'softBlocked':any(blocked(item.get('soft')) for item in radios),'hardBlocked':any(blocked(item.get('hard')) for item in radios),'radioStatusKnown':True}

if __name__=='__main__':
    try:
        if sys.argv[1:]!=['status']:raise ValueError('Usage: forynarch-bluetooth status')
        print(json.dumps(status()))
    except (OSError,ValueError,subprocess.SubprocessError):
        print(json.dumps({'error':'Bluetooth status could not be read.'}),file=sys.stderr)
        raise SystemExit(1)
