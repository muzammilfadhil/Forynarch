-- Built against the installed Hyprland ABI; incompatible plugins refuse load.
local path="/usr/lib/forynarch/hyprbars.so"
local file=io.open(path,"rb")
if not file then return end
file:close()
local loaded=pcall(hl.plugin.load,path)
if not loaded then return end
hl.config({plugin={hyprbars={
    bar_height=32,bar_color="rgba(172639f2)",["col.text"]="rgb(dceaff)",
    bar_text_font="Adwaita Sans",bar_text_size=11,bar_text_align="left",
    bar_buttons_alignment="right",bar_padding=8,bar_button_padding=8,
    bar_part_of_window=true,bar_precedence_over_border=true,bar_blur=false,
    icon_on_hover=false,on_double_click="forynarch-window-control maximize"
}}})
-- Upstream places the first button at the right edge.
for _,button in ipairs({
    {"close","×","rgb(974f5c)"},
    {"fullscreen","⛶","rgb(35516e)"},
    {"maximize","□","rgb(35516e)"},
    {"minimize","−","rgb(35516e)"}
}) do
    hl.plugin.hyprbars.add_button({bg_color=button[3],fg_color="rgb(e4efff)",
        size=20,icon=button[2],action="forynarch-window-control "..button[1]})
end
hl.window_rule({name="forynarch-bars-floating-only",match={float=false},["hyprbars:no_bar"]="true"})
_G.forynarch_titlebars=true
local defaults="/usr/share/forynarch/titlebar-defaults.lua"
local default_file=io.open(defaults,"r")
if default_file then default_file:close();dofile(defaults) end
local custom=(os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME").."/.config")).."/hypr/titlebar-rules.lua"
local custom_file=io.open(custom,"r")
if custom_file then custom_file:close();dofile(custom) end
hl.exec_cmd("forynarch-titlebars apply")
if hl.plugin.hyprbars.supports_app_titles then
    _G.forynarch_webapp_titles=true
    local rules=(os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME").."/.config")).."/hypr/webapp-titles.lua"
    local exists=io.open(rules,"r")
    if exists then exists:close();dofile(rules) end
end
