local callbacks, messages, timer = {}, {}, nil
local pointer = {x=200,y=120}
local monitor = {name="Virtual-1",position={x=0,y=0},size={width=1280,height=800},scale=1,transform=0}
local window = {address="0xabc",mapped=true,visible=true,hidden=false,floating=true,pinned=false,fullscreen=0,
                focus_history_id=0,at={x=100,y=100},size={x=600,y=400}}
hl = {
    get_cursor_pos=function() return pointer end,
    get_monitor_at_cursor=function() return monitor end,
    get_windows=function() return {window} end,
    dispatch=function(message) messages[#messages+1]=message end,
    dsp={event=function(message) return message end},
    bind=function(key,callback,flags)
        assert(flags.non_consuming)
        callbacks[key..(flags.release and ":release" or ":press")]=callback
    end,
    on=function() end,
    timer=function(callback)
        timer={callback=callback,enabled=true,set_enabled=function(self,value) self.enabled=value end}
        return timer
    end
}
dofile(arg[1])
assert(not timer.enabled,"idle polling must be disabled")
local function press() callbacks["mouse:272:press"]() end
local function release() callbacks["mouse:272:release"]() end
press(); release(); assert(#messages==0,"ordinary clicks must not snap")
press(); window.at.x=20;pointer={x=2,y=300};timer.callback()
assert(messages[#messages]=="forynarch-snap,preview,0xabc,Virtual-1,left")
local count=#messages;timer.callback();assert(#messages==count,"preview events must be coalesced")
release();assert(not timer.enabled)
assert(messages[#messages-1]=="forynarch-snap,apply,0xabc,Virtual-1,left")
assert(messages[#messages]=="forynarch-snap,clear,,,")
window.at={x=100,y=100};pointer={x=200,y=120};messages={}
press();window.size.x=500;window.at.x=1;pointer.x=1;timer.callback();release()
assert(#messages==0,"resizing must not be mistaken for a move")
window.size.x=600;window.at={x=100,y=100};pointer={x=200,y=120}
_G.forynarch_snap_enabled=false;press();assert(not timer.enabled);release()
_G.forynarch_snap_enabled=true
window.at={x=100,y=100};pointer={x=200,y=120};messages={}
press();window.at.y=20;pointer={x=640,y=1};timer.callback()
assert(messages[#messages]=="forynarch-snap,preview-top,0xabc,Virtual-1,top","top edge must not maximize")
for _, choice in ipairs({{448,"left"},{544,"top-left"},{640,"top"},{736,"top-right"},{832,"right"}}) do
 pointer={x=choice[1],y=95};timer.callback()
 assert(messages[#messages]=="forynarch-snap,preview-top,0xabc,Virtual-1,"..choice[2])
end
release()
assert(messages[#messages-1]=="forynarch-snap,apply,0xabc,Virtual-1,right")
monitor={name="Rotated",position={x=-1920,y=0},size={width=1920,height=1080},scale=1.5,transform=1}
window.at={x=-1800,y=100};pointer={x=-1780,y=120};messages={}
press();window.at.x=-1700;pointer={x=-1201,y=400};timer.callback();release()
assert(messages[#messages-1]=="forynarch-snap,apply,0xabc,Rotated,right")
print("AUTO_SNAP_INPUT_AND_GEOMETRY_OK")
