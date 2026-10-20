"""Run as the Live QA user with its desktop D-Bus/Wayland environment."""
import json
import os
from pathlib import Path
import subprocess
import time

assert os.getuid()==1000 and Path('/run/archiso').exists()
assert os.environ.get('FORYNARCH_QA_PRODUCT_UUID') in {'7ec3f658-f099-fa47-91c2-2b4ce875bf22','e299bc66-1045-ef4e-95c5-8fb979457c6c'}


def call(action,value=None):
    result=subprocess.run(['forynarch-notifications',action],input=json.dumps(value or {}),text=True,capture_output=True,timeout=15)
    assert result.returncode==0,result.stderr
    return json.loads(result.stdout)


def banners():
    data=json.loads(subprocess.check_output(['hyprctl','-j','layers'],text=True))
    return [layer for screen in data.values() for group in screen['levels'].values() for layer in group if layer.get('namespace')=='notifications']


def send(app,title,critical=False):
    args=['notify-send','--print-id','-a',app,'-t','3000']
    if critical:args+=['-u','critical']
    return int(subprocess.check_output([*args,title,'Native notification fixture.'],text=True))


saved=call('status')['settings']
try:
    call('clear');settings={**saved,'enabled':True,'profile':'dnd','timeout':3}
    data=call('set',settings);assert data['dnd']
    key=send('Blocked','DND fixture',True);time.sleep(.3)
    assert any(row['id']==key for row in call('status')['current'])
    assert not banners(),'DND exposed a banner'
    print('DND_SUPPRESSES_CRITICAL_WITHOUT_DROPPING_NOTIFICATION_OK',flush=True)
    call('clear');settings.update(profile='custom',allow=['Allowed'],critical=False)
    call('set',settings);send('Blocked','Blocked custom fixture',True);time.sleep(.3)
    assert not banners(),'Custom focus exposed a blocked critical banner'
    key=send('Allowed','Allowed custom fixture');time.sleep(.3)
    assert banners(),'An allowed application did not show a banner'
    print('CUSTOM_ALLOWLIST_AND_CRITICAL_POLICY_NATIVE_OK',flush=True)
    call('dismiss',{'id':key})
    data=call('status');assert any(row['id']==key for row in data['history'])
    call('clear');settings['profile']='normal';call('set',settings)
    action=subprocess.Popen(['notify-send','--print-id','--wait','--action=default=Open','-a','Forynarch','Action fixture'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        for _ in range(50):
            row=next((row for row in call('status')['current'] if row['title']=='Action fixture'),None)
            if row:break
            time.sleep(.1)
        assert row
        call('invoke',{'id':row['id'],'action':'default'})
        out,err=action.communicate(timeout=5)
        assert action.returncode==0 and 'default' in out,(out,err)
    finally:
        if action.poll() is None:action.terminate();action.wait(timeout=5)
    print('NATIVE_NOTIFICATION_ACTION_AND_DISMISSED_HISTORY_OK',flush=True)
finally:
    call('clear');call('set',saved)
