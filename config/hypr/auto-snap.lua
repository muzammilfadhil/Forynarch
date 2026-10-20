-- Observe drags without consuming the application's pointer events.
if _G.forynarch_snap_loaded then return end
_G.forynarch_snap_loaded = true
if _G.forynarch_snap_enabled == nil then _G.forynarch_snap_enabled = true end

local gesture, preview
local function emit(action, window, monitor, region)
    hl.dispatch(hl.dsp.event(table.concat({"forynarch-snap", action, window or "", monitor or "", region or ""}, ",")))
end
local function clear()
    if preview then emit("clear") end
    preview = nil
end
local function region_at_cursor()
    local monitor = hl.get_monitor_at_cursor()
    if not monitor then return end
    local cursor = hl.get_cursor_pos()
    local width, height = monitor.size.width, monitor.size.height
    if monitor.transform % 2 == 1 then width, height = height, width end
    width, height = width / monitor.scale, height / monitor.scale
    local x, y = cursor.x - monitor.position.x, cursor.y - monitor.position.y
 if y <= 10 and gesture then gesture.palette_monitor = monitor.name end
 if gesture and gesture.palette_monitor == monitor.name then
  if y > 144 then gesture.palette_monitor = nil
  else
   local tray = math.min(488, width - 32)
   local offset = x - (width - tray) / 2 - 8
   if offset >= 0 and offset < tray - 16 then
    local choices = {"left", "top-left", "top", "top-right", "right"}
    local index = math.min(5, math.floor(offset / ((tray - 8) / 5)) + 1)
    return choices[index], monitor.name
   end
  end
 end
    local region
    if x <= 56 and y <= 72 then region = "top-left"
    elseif x >= width - 56 and y <= 72 then region = "top-right"
    elseif x <= 56 and y >= height - 72 then region = "bottom-left"
    elseif x >= width - 56 and y >= height - 72 then region = "bottom-right"
    elseif x <= 12 then region = "left"
    elseif x >= width - 12 then region = "right"
 elseif y <= 10 then region = "top"
    elseif y >= height - 12 then region = "bottom" end
    return region, monitor.name
end
local function moved()
    if not gesture or not _G.forynarch_snap_enabled then return false end
    local window = gesture.window
    if not window.mapped or window.hidden or not window.floating or window.fullscreen ~= 0 then return false end
    local at, size = window.at, window.size
    if not at or not size then return false end
    if math.abs(size.x - gesture.width) > 4 or math.abs(size.y - gesture.height) > 4 then return false end
    return math.abs(at.x - gesture.x) + math.abs(at.y - gesture.y) >= 8
end
local watch = hl.timer(function()
    if not moved() then clear(); return end
    local region, monitor = region_at_cursor()
 local choices = gesture.palette_monitor == monitor
 local key = region and (monitor .. ":" .. region .. (choices and ":choices" or "")) or nil
    if key == preview then return end
    clear()
    if region then
        preview = key
  emit(choices and "preview-top" or "preview", gesture.window.address, monitor, region)
    end
end, {timeout = 40, type = "repeat"})
watch:set_enabled(false)

local function start()
    clear(); gesture = nil; watch:set_enabled(false)
    if not _G.forynarch_snap_enabled then return end
    local cursor, selected = hl.get_cursor_pos(), nil
    for _, window in ipairs(hl.get_windows()) do
        local at, size = window.at, window.size
        if window.mapped and window.visible and not window.hidden and window.floating and not window.pinned and at and size
            and cursor.x >= at.x and cursor.x < at.x + size.x and cursor.y >= at.y and cursor.y < at.y + size.y then
            if not selected or window.focus_history_id < selected.focus_history_id then selected = window end
        end
    end
    if not selected then return end
    gesture = {window=selected, x=selected.at.x, y=selected.at.y, width=selected.size.x, height=selected.size.y}
    watch:set_enabled(true)
end
local function finish()
    watch:set_enabled(false)
    if moved() then
        local region, monitor = region_at_cursor()
        if region then emit("apply", gesture.window.address, monitor, region) end
    end
    clear(); gesture = nil
end
_G.forynarch_snap_rebind = function(keys)
    for _, key in ipairs(keys) do
        if key:match("mouse:272$") then
            hl.bind(key, start, {non_consuming=true, description="Observe floating drag"})
            hl.bind(key, finish, {non_consuming=true, release=true, description="Finish floating snap"})
        end
    end
end
local keys = {}
for mask = 0, 15 do
    local parts = {}
    for bit, name in ipairs({"SUPER", "CTRL", "ALT", "SHIFT"}) do
        if math.floor(mask / (2 ^ (bit - 1))) % 2 == 1 then parts[#parts + 1] = name end
    end
    parts[#parts + 1] = "mouse:272"
    keys[#keys + 1] = table.concat(parts, " + ")
end
_G.forynarch_snap_rebind(keys)
