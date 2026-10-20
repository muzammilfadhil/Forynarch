#!/usr/bin/env python3
"""Route existing user audio streams through WirePlumber metadata."""
import json
import subprocess
import sys

DEVICES = {'output':'Audio/Sink','input':'Audio/Source'}
STREAMS = {'output':'Stream/Output/Audio','input':'Stream/Input/Audio'}

def command(args):
    result = subprocess.run(args,check=True,capture_output=True,text=True,timeout=5)
    if len(result.stdout)>16*1024**2:raise ValueError('The audio graph is too large to display.')
    return result.stdout

def inventory():return json.loads(command(['pw-dump']))

def properties(node):return node.get('info',{}).get('props',{})

def app_key(props,node_id):
    return str(props.get('application.id') or props.get('application.process.binary') or props.get('application.name') or node_id)

def snapshot(graph):
    targets={}
    for obj in graph:
        if obj.get('type')=='PipeWire:Interface:Metadata' and obj.get('props',{}).get('metadata.name')=='default':
            for entry in obj.get('metadata',[]):
                if entry.get('key')=='target.object':targets[int(entry['subject'])]=str(entry.get('value',''))
    devices={'output':[],'input':[]};apps={}
    for node in graph:
        if node.get('type')!='PipeWire:Interface:Node':continue
        props=properties(node);kind=props.get('media.class');serial=str(props.get('object.serial',''))
        if not serial.isdecimal():continue
        for direction,device_class in DEVICES.items():
            if kind==device_class:devices[direction].append({'serial':serial,'name':props.get('node.description') or props.get('node.nick') or props.get('node.name',serial)})
        for direction,stream_class in STREAMS.items():
            if kind!=stream_class:continue
            key=app_key(props,node['id'])
            app=apps.setdefault(key,{'key':key,'name':props.get('application.name') or props.get('node.description') or key,'output':[],'input':[]})
            app[direction].append({'id':node['id'],'serial':serial,'target':targets.get(node['id'],'app')})
    names={str(properties(node).get('node.name')):str(properties(node).get('object.serial')) for node in graph if node.get('type')=='PipeWire:Interface:Node'}
    for app in apps.values():
        for direction in STREAMS:
            for stream in app[direction]:stream['target']=names.get(stream['target'],stream['target'])
    return {'devices':devices,'apps':list(apps.values())}

def route(request,graph):
    if not isinstance(request,dict) or set(request)!={'streams','direction','target'}:raise ValueError('Choose an application stream and device.')
    direction=request['direction'];target=request['target'];selected=request['streams']
    if direction not in STREAMS or not isinstance(target,str) or not isinstance(selected,list) or not 1<=len(selected)<=64:raise ValueError('Invalid audio route.')
    nodes={node['id']:node for node in graph if node.get('type')=='PipeWire:Interface:Node'}
    for item in selected:
        if not isinstance(item,dict) or set(item)!={'id','serial'} or type(item['id']) is not int:raise ValueError('The audio stream changed. Refresh and try again.')
        props=properties(nodes.get(item['id'],{}))
        if props.get('media.class')!=STREAMS[direction] or str(props.get('object.serial'))!=str(item['serial']):raise ValueError('The audio stream changed. Refresh and try again.')
        if direction=='input' and props.get('stream.capture.sink') in (True,'true'):raise ValueError('This app records a monitor source. Choose its capture source inside the app.')
        if target=='default' and props.get('node.dont-fallback') in (True,'true'):raise ValueError('This app requires a specific device. Choose a device or use its own audio settings.')
    if target not in ('default','app'):
        if not target.isdecimal() or not any(properties(node).get('media.class')==DEVICES[direction] and str(properties(node).get('object.serial'))==target for node in nodes.values()):raise ValueError('The audio device disconnected. Choose another device.')
    for item in selected:
        args=['pw-metadata','-n','default']
        if target=='app':args+=['-d',str(item['id']),'target.object']
        else:args += [str(item['id']),'target.object','0' if target=='default' else target,'Spa:String']
        command(args)

def main():
    if sys.argv[1:] not in (['status'],['route']):raise ValueError('Usage: forynarch-audio status | route')
    graph=inventory()
    if sys.argv[1]=='route':
        payload=sys.stdin.read(65537)
        if len(payload)>65536:raise ValueError('The audio request is too large.')
        route(json.loads(payload),graph);graph=inventory()
    print(json.dumps(snapshot(graph)))

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:
        message=str(error) if isinstance(error,ValueError) else 'The audio service could not apply this route. Try again after the app starts playing or recording.'
        print(json.dumps({'error':message}),file=sys.stderr)
        raise SystemExit(1)
