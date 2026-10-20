local callback, moves
hl={config=function() end,plugin={load=function() end},window_rule=function() end,unbind=function() end,bind=function() end,
    on=function(_, fn) callback=fn end,dispatch=function(value) moves[#moves+1]=value end,
    dsp={cursor={move=function(value) return value end},window={drag=function() end,resize=function() end}}}
dofile(arg[1] or "config/hypr/windows.lua")
local function check(window,reason,expected)
    moves={};callback(window,reason);assert(#moves==expected,"Unexpected cursor dispatch count")
end
local valid={mapped=true,at={x=-1600,y=80},size={x=800,y=600}}
check(nil,2,0)
check(setmetatable({},{__index=function() return nil end}),2,0)
check({mapped=true},2,0)
check({mapped=true,at={},size={}},2,0)
check({mapped=true,at={x=0,y=0},size={x=0,y=10}},2,0)
check({mapped=true,at={x=0/0,y=0},size={x=10,y=10}},2,0)
check({mapped=true,at={x=0,y=0},size={x=math.huge,y=10}},2,0)
check(valid,1,0)
check(valid,2,1);assert(moves[1].x==-1200 and moves[1].y==380)
valid.floating=true;check(valid,2,0)
valid.floating=false;valid.hidden=true;check(valid,2,0)
valid.hidden=false;valid.mapped=false;check(valid,2,0)
print("PASS focus cursor: expired, incomplete, hidden, unmapped, floating and invalid geometry; tiled center on negative monitor")
