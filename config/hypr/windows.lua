hl.config({general={resize_on_border=true,extend_border_grab_area=12,snap={enabled=true,window_gap=10,monitor_gap=10}}})
hl.config({dwindle={smart_resizing=true,preserve_split=true},input={follow_mouse=0,float_switch_override_focus=0}})
hl.config({cursor={no_warps=true,warp_back_after_non_mouse_input=false}})
local controls_plugin="/usr/lib/forynarch/forynarch-window-controls.so"
local controls_file=io.open(controls_plugin,"rb")
if controls_file then controls_file:close();hl.plugin.load(controls_plugin) end
if not _G.forynarch_focus_cursor then
    _G.forynarch_focus_cursor=true
    hl.on("window.active",function(window,reason)
if not window or window.mapped~=true or window.hidden or window.floating or not ({[2]=true,[3]=true,[8]=true,[9]=true,[10]=true})[reason] then return end
        local at,size=window.at,window.size
-- Expired Lua window references return nil for every property.
if type(at)~="table" or type(size)~="table" then return end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
if not finite(at.x) or not finite(at.y) or not finite(size.x) or not finite(size.y) or size.x<=0 or size.y<=0 then return end
        hl.dispatch(hl.dsp.cursor.move({x=at.x+size.x/2,y=at.y+size.y/2}))
    end)
end
-- The packaged example suppresses native maximize requests from every app.
hl.window_rule({name="suppress-maximize-events",match={class=".*"},suppress_event="maximize",enabled=false})
hl.unbind("SUPER + mouse:272")
hl.bind("SUPER + mouse:272",hl.dsp.window.drag(),{mouse=true,description="Move window"})
hl.unbind("SUPER + mouse:273")
hl.bind("SUPER + mouse:273",hl.dsp.window.resize(),{mouse=true,description="Resize window"})
