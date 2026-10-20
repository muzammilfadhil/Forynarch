"""A disposable MPRIS producer; this is not the Mudil Music application."""
import os
from pathlib import Path
import time
from gi.repository import Gio, GLib

assert os.getuid()==1000
assert os.environ.get('FORYNARCH_QA_PRODUCT_UUID')=='e299bc66-1045-ef4e-95c5-8fb979457c6c'
PATH='/org/mpris/MediaPlayer2'
NAME='org.mpris.MediaPlayer2.me.muzammilfadhil.mudilmusic.qa'
Path('/tmp/forynarch-media-art.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#17304a"/><path d="M20 100 64 20l44 80Z" fill="#9acbff"/><circle cx="64" cy="72" r="15" fill="#17304a"/></svg>')
root='org.mpris.MediaPlayer2'
player=root+'.Player'
types={'Identity':'s','DesktopEntry':'s','CanQuit':'b','CanRaise':'b','HasTrackList':'b','SupportedUriSchemes':'as','SupportedMimeTypes':'as',
       'PlaybackStatus':'s','LoopStatus':'s','Rate':'d','Shuffle':'b','Metadata':'a{sv}','Volume':'d','Position':'x',
       'MinimumRate':'d','MaximumRate':'d','CanGoNext':'b','CanGoPrevious':'b','CanPlay':'b','CanPause':'b','CanSeek':'b','CanControl':'b'}
values={root:{'Identity':'Mudil Music QA fixture','DesktopEntry':'me.muzammilfadhil.mudilmusic','CanQuit':False,'CanRaise':False,'HasTrackList':False,'SupportedUriSchemes':['file'],'SupportedMimeTypes':['audio/wav']},
        player:{'PlaybackStatus':'Playing','LoopStatus':'None','Rate':1.0,'Shuffle':False,'Volume':0.5,'Position':10_000_000,
                'MinimumRate':1.0,'MaximumRate':1.0,'CanGoNext':True,'CanGoPrevious':True,'CanPlay':True,'CanPause':True,'CanSeek':True,'CanControl':True}}
def metadata(title):
    return {'mpris:trackid':GLib.Variant('o','/forynarch/track/'+('one' if title.startswith('Forynarch') else 'two')),
            'mpris:length':GLib.Variant('x',300_000_000),'mpris:artUrl':GLib.Variant('s','file:///tmp/forynarch-media-art.svg'),
            'xesam:title':GLib.Variant('s',title),'xesam:artist':GLib.Variant('as',['Protocol fixture']),
            'xesam:album':GLib.Variant('s','Forynarch QA'),
            'xesam:asText':GLib.Variant('s','First fixture lyric line\nSecond fixture lyric line\nThird fixture lyric line')}
values[player]['Metadata']=metadata('Forynarch audio fixture')
started=time.monotonic()
connection=None
def get(conn,sender,path,interface,name,*_):
    value=values[interface][name]
    if name=='Position' and values[player]['PlaybackStatus']=='Playing':value+=int((time.monotonic()-started)*1_000_000)
    return GLib.Variant(types[name],value)
def emit(interface,name):
    connection.emit_signal(None,PATH,'org.freedesktop.DBus.Properties','PropertiesChanged',GLib.Variant('(sa{sv}as)',(interface,{name:GLib.Variant(types[name],values[interface][name])},[])))
def set_value(conn,sender,path,interface,name,value,*_):
    values[interface][name]=value.unpack();emit(interface,name);return True
def method(conn,sender,path,interface,name,parameters,invocation,*_):
    if name in ('Play','Pause','PlayPause','Stop'):
        values[player]['PlaybackStatus']='Paused' if name in ('Pause','Stop') or (name=='PlayPause' and values[player]['PlaybackStatus']=='Playing') else 'Playing'
        emit(player,'PlaybackStatus')
    if name in ('Next','Previous'):
        values[player]['Metadata']=metadata('Second fixture track' if name=='Next' else 'Forynarch audio fixture');emit(player,'Metadata')
    if name=='SetPosition':values[player]['Position']=parameters.unpack()[1]
    invocation.return_value(GLib.Variant('()',()))
interfaces=[]
for interface,props in values.items():
    xml='<node><interface name="'+interface+'">'
    xml+=''.join('<property name="'+name+'" type="'+types[name]+'" access="'+('readwrite' if name in ('Volume','Shuffle','LoopStatus','Rate') else 'read')+'"/>' for name in props)
    if interface==player:
        xml+=''.join('<method name="'+name+'"/>' for name in ('Play','Pause','PlayPause','Stop','Next','Previous'))
        xml+='<method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>'
    xml+='</interface></node>'
    interfaces.append(Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0])
def acquired(conn,*_):
    global connection
    connection=conn
    for interface in interfaces:conn.register_object(PATH,interface,method,get,set_value)
Gio.bus_own_name(Gio.BusType.SESSION,NAME,Gio.BusNameOwnerFlags.NONE,acquired,lambda *_:print('MPRIS_PROTOCOL_FIXTURE_READY',flush=True),None)
GLib.MainLoop().run()
