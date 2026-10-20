"""Reversible geometry checks using a separately identified QA terminal."""
import json,os,runpy,subprocess,time
from pathlib import Path
assert os.getuid()==1000 and os.environ.get('FORYNARCH_QA_PRODUCT_UUID') in {'7ec3f658-f099-fa47-91c2-2b4ce875bf22','e299bc66-1045-ef4e-95c5-8fb979457c6c'}
api=runpy.run_path('/usr/local/bin/forynarch-window-control',run_name='support')
query,dispatch=api['query'],api['dispatch']
previous=query('activewindow').get('address')
child=subprocess.Popen(['alacritty','--class','ForynarchMaximizeQA','--title','Forynarch maximize geometry fixture','-e','/usr/bin/sleep','600'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True,env={**os.environ,'LIBGL_ALWAYS_SOFTWARE':'1'})
address=None
try:
    for _ in range(100):
        if child.poll() is not None:raise AssertionError(child.stderr.read())
        row=next((c for c in query('clients') if c['pid']==child.pid),None)
        if row:address=row['address'];break
        time.sleep(.1)
    assert address,'The fixture terminal did not open'
    for floating in (True,False):
        dispatch('fullscreen',address,mode='maximized',action='unset')
        dispatch('float',address,action='on' if floating else 'off')
        if floating:
            dispatch('resize',address,x=400,y=300)
            dispatch('move',address,x=100,y=100)
        time.sleep(.4)
        original=next(c for c in query('clients') if c['address']==address)
        subprocess.run(['forynarch-window-control','maximize',address],check=True)
        time.sleep(.7)
        row=next(c for c in query('clients') if c['address']==address)
        monitor=next(m for m in query('monitors') if m['id']==row['monitor'])
        width,height=monitor['width'],monitor['height']
        if monitor.get('transform',0)%2:width,height=height,width
        left,top,right,bottom=monitor['reserved']
        bounds=[monitor['x']+left,monitor['y']+top,monitor['x']+width/monitor['scale']-right,monitor['y']+height/monitor['scale']-bottom]
        x,y=row['at'];w,h=row['size']
        print(json.dumps({'floating':floating,'at':row['at'],'size':row['size'],'bounds':bounds,'fullscreen':row['fullscreen']}),flush=True)
        assert x>=bounds[0]-1 and y>=bounds[1]-1 and x+w<=bounds[2]+1 and y+h<=bounds[3]+1,'Maximize exceeded the usable monitor area'
        subprocess.run(['forynarch-window-control','maximize',address],check=True)
        time.sleep(.7)
        restored=next(c for c in query('clients') if c['address']==address)
        assert restored['fullscreen']==0 and restored['floating']==floating
        if floating:
            assert all(abs(a-b)<=2 for key in ('at','size') for a,b in zip(original[key],restored[key])),'Maximize did not restore the manual floating geometry'
    print('NATIVE_FLOATING_AND_TILED_MAXIMIZE_STAY_INSIDE_PANEL_WORKAREA_OK',flush=True)
finally:
    if address:
        dispatch('close',address)
    try:child.wait(timeout=5)
    except subprocess.TimeoutExpired:child.terminate();child.wait(timeout=5)
    if previous:
        api['hypr']('dispatch','hl.dsp.focus({window='+json.dumps('address:'+previous)+'})')
