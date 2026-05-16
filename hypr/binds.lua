-- Keybindings
-- Based on configs/Keybinds.conf, UserConfigs/Laptops.conf, and UserConfigs/UserKeybinds.conf

local proc    = require("utils.proc")

local mod = "SUPER"
local scriptsDir = configDir .. "/scripts"

-- Default applications live in user-functions/system.lua (TERMINAL / FILE_MANAGER)

-- ============================================
-- CORE BINDS (from configs/Keybinds.conf)
-- ============================================

-- Session management
hl.bind("CTRL + ALT + Delete", hl.dsp.exit(),                                            { desc = "Exit Hyprland" })
hl.bind(mod .. " + Q",         hl.dsp.window.close(),                                    { desc = "Close active window" })
hl.bind(mod .. " + SHIFT + Q", function() user.window.kill_active() end,                 { desc = "Kill active window" })
hl.bind("CTRL + ALT + L",      function() user.session.lock() end,                       { desc = "Lock screen" })
hl.bind("CTRL + ALT + P",      function() user.session.logout() end,                     { desc = "Power menu" })

-- Notifications and settings
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"),                 { desc = "Toggle notification panel" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd(scriptsDir .. "/Kool_Quick_Settings.sh"),{ desc = "Hyprland settings menu" })

-- Master Layout (only works when layout=master)
hl.bind(mod .. " + CTRL + D",      hl.dsp.layout("removemaster"),                       { desc = "Remove master (master layout)" })
hl.bind(mod .. " + I",             hl.dsp.layout("addmaster"),                           { desc = "Add master (master layout)" })
hl.bind(mod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster master"),               { desc = "Swap with master" })

-- Window cycling (works in any layout). Note: SUPER+K is taken by the
-- keepassxc special-workspace toggle further down — only J cycles here.
hl.bind(mod .. " + J", hl.dsp.window.cycle_next(), { desc = "Cycle to next window" })

-- Dwindle Layout
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { desc = "Toggle pseudo-tiling (dwindle)" })

-- Layout resize (dwindle's splitratio layoutmsg)
hl.bind(mod .. " + M", hl.dsp.layout("splitratio 0.3"), { desc = "Adjust split ratio" })

-- Group management
hl.bind(mod .. " + G",        hl.dsp.group.toggle(),   { desc = "Toggle window group" })
hl.bind(mod .. " + CTRL + Tab", hl.dsp.group.next(),   { desc = "Next window in group" })

-- Window cycling
hl.bind("ALT + Tab", function()
  hl.dispatch(hl.dsp.window.cycle_next())
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, { desc = "Cycle windows (alt-tab)" })

-- Media controls (locked + repeating)
hl.bind("XF86AudioRaiseVolume", function() user.audio.volume_up() end,     { locked = true, repeating = true, desc = "Volume up" })
hl.bind("XF86AudioLowerVolume", function() user.audio.volume_down() end,   { locked = true, repeating = true, desc = "Volume down" })
hl.bind("XF86AudioMicMute",     function() user.audio.mic_toggle() end,    { locked = true, desc = "Toggle mic mute" })
hl.bind("XF86AudioMute",        function() user.audio.volume_toggle() end, { locked = true, desc = "Toggle mute" })
hl.bind("XF86Sleep",            hl.dsp.exec_cmd("systemctl suspend"),      { locked = true, desc = "Suspend" })
hl.bind("XF86Rfkill",           function() user.system.airplane_mode() end,{ locked = true, desc = "Toggle airplane mode" })

-- Media playback controls
hl.bind("XF86AudioPlay", function() user.audio.media_play() end,  { locked = true, desc = "Play/pause media" })
hl.bind("XF86AudioPause", function() user.audio.media_play() end, { locked = true, desc = "Play/pause media" })
hl.bind("XF86AudioNext",  function() user.audio.media_next() end, { locked = true, desc = "Next track" })
hl.bind("XF86AudioPrev",  function() user.audio.media_prev() end, { locked = true, desc = "Previous track" })
hl.bind("XF86AudioStop",  function() user.audio.media_stop() end, { locked = true, desc = "Stop media" })

-- Screenshots
hl.bind(mod .. " + Print",              function() user.session.screenshot("now") end,    { desc = "Screenshot" })
hl.bind(mod .. " + SHIFT + Print",      function() user.session.screenshot("area") end,   { desc = "Screenshot region" })
hl.bind(mod .. " + CTRL + Print",       function() user.session.screenshot("5") end,      { desc = "Screenshot (5s timer)" })
hl.bind(mod .. " + CTRL + SHIFT + Print", function() user.session.screenshot("10") end,   { desc = "Screenshot (10s timer)" })
hl.bind("ALT + Print",                  function() user.session.screenshot("window") end, { desc = "Screenshot active window" })
hl.bind(mod .. " + SHIFT + S",          function() user.session.screenshot("swappy") end, { desc = "Screenshot to swappy" })

-- Resize windows (repeating)
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true, desc = "Shrink window left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50,  y = 0, relative = true }), { repeating = true, desc = "Grow window right" })
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true, desc = "Shrink window up" })
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,  y = 50, relative = true }), { repeating = true, desc = "Grow window down" })

-- Move windows
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }), { desc = "Move window left" })
hl.bind(mod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }), { desc = "Move window right" })
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }), { desc = "Move window up" })
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }), { desc = "Move window down" })

-- Swap windows
hl.bind(mod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }), { desc = "Swap window left" })
hl.bind(mod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }), { desc = "Swap window right" })
hl.bind(mod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }), { desc = "Swap window up" })
hl.bind(mod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }), { desc = "Swap window down" })

-- Focus movement
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "l" }), { desc = "Focus left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }), { desc = "Focus right" })
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "u" }), { desc = "Focus up" })
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "d" }), { desc = "Focus down" })

-- Workspace navigation
hl.bind(mod .. " + Tab",         hl.dsp.focus({ workspace = "m+1" }), { desc = "Next workspace" })
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }), { desc = "Previous workspace" })

-- Special workspace
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special" }), { desc = "Move to scratchpad" })
hl.bind(mod .. " + U",         hl.dsp.workspace.toggle_special(),              { desc = "Toggle scratchpad" })

-- Workspace binds (1-10) using loops
for i = 1, 9 do
  local key = tostring(i)
  hl.bind(mod .. " + code:" .. tostring(9 + i),              hl.dsp.focus({ workspace = i }),                      { desc = "Go to workspace " .. key })
  hl.bind(mod .. " + SHIFT + code:" .. tostring(9 + i),      hl.dsp.window.move({ workspace = i }),                { desc = "Move window to workspace " .. key })
  hl.bind(mod .. " + CTRL + code:" .. tostring(9 + i),       hl.dsp.window.move({ workspace = i, silent = true }), { desc = "Silently move to workspace " .. key })
end

hl.bind(mod .. " + code:19",              hl.dsp.focus({ workspace = 10 }),                      { desc = "Go to workspace 10" })
hl.bind(mod .. " + SHIFT + code:19",      hl.dsp.window.move({ workspace = 10 }),                { desc = "Move window to workspace 10" })
hl.bind(mod .. " + CTRL + code:19",       hl.dsp.window.move({ workspace = 10, silent = true }), { desc = "Silently move to workspace 10" })

-- Move to workspace with bracket keys
hl.bind(mod .. " + SHIFT + bracketleft",   hl.dsp.window.move({ workspace = "-1" }),               { desc = "Move window to previous workspace" })
hl.bind(mod .. " + SHIFT + bracketright",  hl.dsp.window.move({ workspace = "+1" }),               { desc = "Move window to next workspace" })
hl.bind(mod .. " + CTRL + bracketleft",    hl.dsp.window.move({ workspace = "-1", silent = true }), { desc = "Silently move window to previous workspace" })
hl.bind(mod .. " + CTRL + bracketright",   hl.dsp.window.move({ workspace = "+1", silent = true }), { desc = "Silently move window to next workspace" })

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace (scroll)" })
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace (scroll)" })
hl.bind(mod .. " + period",     hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mod .. " + comma",      hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, desc = "Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Resize window" })

-- ============================================
-- LAPTOP BINDS (from UserConfigs/Laptops.conf)
-- ============================================

hl.bind("XF86KbdBrightnessDown", function() user.display.kbd_brightness_down() end, { locked = true, repeating = true, desc = "Keyboard brightness down" })
hl.bind("XF86KbdBrightnessUp",   function() user.display.kbd_brightness_up() end,   { locked = true, repeating = true, desc = "Keyboard brightness up" })
hl.bind("XF86Launch1",           hl.dsp.exec_cmd("rog-control-center"),              { desc = "ROG control center" })
hl.bind("XF86Launch3",           hl.dsp.exec_cmd("asusctl led-mode -n"),             { desc = "Next ASUS LED mode" })
hl.bind("XF86Launch4",           hl.dsp.exec_cmd("asusctl profile -n"),              { desc = "Next ASUS performance profile" })
hl.bind("XF86MonBrightnessDown", function() user.display.brightness_down() end,      { locked = true, repeating = true, desc = "Screen brightness down" })
hl.bind("XF86MonBrightnessUp",   function() user.display.brightness_up() end,        { locked = true, repeating = true, desc = "Screen brightness up" })
hl.bind("XF86TouchpadToggle",    function() user.system.touchpad_toggle() end,       { desc = "Toggle touchpad" })

-- Screenshot alternatives for laptops without Print key
hl.bind(mod .. " + F11",              function() user.session.screenshot("now") end,  { desc = "Screenshot" })
hl.bind(mod .. " + SHIFT + F11",      function() user.session.screenshot("area") end, { desc = "Screenshot region" })
hl.bind(mod .. " + CTRL + F11",       function() user.session.screenshot("window") end, { desc = "Screenshot active window" })

-- ============================================
-- USER BINDS (from UserConfigs/UserKeybinds.conf)
-- ============================================

hl.bind("F12",        hl.dsp.exec_cmd("kitten quick-access-terminal"),               { desc = "Drop-down terminal" })
hl.bind(mod .. " + F12", hl.dsp.exec_cmd("kitten quick-access-terminal"),            { locked = true, desc = "Drop-down terminal" })

-- Application launchers
hl.bind(mod .. " + SPACE",  hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"), { desc = "Application launcher" })
hl.bind(mod .. " + B",      hl.dsp.exec_cmd('xdg-open "https://"'),                 { desc = "Launch browser" })
hl.bind(mod .. " + A",      hl.dsp.exec_cmd("pkill rofi || true && ags -t 'overview'"), { desc = "Desktop overview" })
hl.bind(mod .. " + Return", function() user.system.terminal() end,                   { desc = "Terminal" })
hl.bind(mod .. " + E",      function() user.system.file_manager() end,               { desc = "File manager" })

-- Special applications
hl.bind(mod .. " + S", function()
  if proc.running("signal", false) then
    hl.dispatch(hl.dsp.workspace.toggle_special("signal"))
  else
    hl.dispatch(hl.dsp.exec_cmd("gtk-launch org.signal.Signal"))
  end
end, { desc = "Toggle Signal" })

hl.bind(mod .. " + K", hl.dsp.workspace.toggle_special("keepassxc"), { desc = "Toggle KeePassXC" })
hl.bind(mod .. " + D", hl.dsp.exec_cmd(scriptsDir .. "/DevTools.rb"), { desc = "Dev tools menu" })

-- Features and extras
hl.bind(mod .. " + H",             function() user.session.show_hints() end,          { desc = "Keybind cheat sheet" })
hl.bind(mod .. " + ALT + R",       function()
    local refresh = require("utils.refresh")
    refresh.refresh_ui()
end,                                                                                   { desc = "Reload waybar/swaync/rofi" })
hl.bind(mod .. " + ALT + E",       function() user.rofi.emoji() end,                  { desc = "Emoji picker" })
hl.bind(mod .. " + CTRL + S",      hl.dsp.exec_cmd("rofi -show window"),              { desc = "Window switcher" })
hl.bind(mod .. " + ALT + O",       function() user.display.blur_toggle() end,         { desc = "Toggle blur" })
hl.bind(mod .. " + SHIFT + G",     function() user.window.game_mode() end,            { desc = "Toggle game mode" })
hl.bind(mod .. " + ALT + L",       function() user.window.layout_toggle() end,        { desc = "Toggle dwindle/master layout" })
hl.bind(mod .. " + ALT + V",       function() user.system.clipboard_manager() end,    { desc = "Clipboard manager" })
hl.bind(mod .. " + CTRL + R",      function() user.rofi.theme_selector() end,         { desc = "Rofi theme selector" })
hl.bind(mod .. " + CTRL + SHIFT + R", function() user.rofi.theme_selector() end,      { desc = "Rofi theme selector v2" })

-- Window management
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen(),                            { desc = "Toggle fullscreen" })
hl.bind(mod .. " + CTRL + F",  hl.dsp.window.fullscreen({ mode = 1 }),                { desc = "Toggle fake fullscreen" })
hl.bind(mod .. " + F",         hl.dsp.window.float(),                                 { desc = "Toggle float" })
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"), { desc = "Toggle all windows float" })

-- Desktop zoom/magnifier
local function zoom(scale)
  return function()
    local f = tonumber(hl.get_config("cursor.zoom_factor")) or 1
    if f < 1 then f = 1 end
    hl.config({ cursor = { zoom_factor = f * scale } })
  end
end

hl.bind(mod .. " + ALT + mouse_down", zoom(2.0), { desc = "Zoom in" })
hl.bind(mod .. " + ALT + mouse_up",  zoom(0.5),  { desc = "Zoom out" })

-- Waybar controls
hl.bind(mod .. " + CTRL + ALT + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"),        { desc = "Hide/show waybar" })
hl.bind(mod .. " + CTRL + B",       function() user.waybar.select_style() end,        { desc = "Waybar style selector" })
hl.bind(mod .. " + ALT + B",        function() user.waybar.select_layout() end,       { desc = "Waybar layout selector" })

-- Night light (Hyprsunset)
hl.bind(mod .. " + N", function() user.display.nightlight_toggle() end, { desc = "Toggle night light" })

-- Scripts features
hl.bind(mod .. " + SHIFT + M",      function() user.rofi.beats() end,                 { desc = "Music player" })
hl.bind(mod .. " + W",              function() user.wallpaper.select() end,            { desc = "Wallpaper selector" })
hl.bind(mod .. " + SHIFT + W",      function() user.wallpaper.effects() end,           { desc = "Wallpaper effects" })
hl.bind("CTRL + ALT + W",           function() user.wallpaper.random() end,            { desc = "Random wallpaper" })
hl.bind(mod .. " + CTRL + O",       hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), { desc = "Toggle window opacity" })
hl.bind(mod .. " + SHIFT + K",      function() user.session.show_binds() end,         { desc = "Searchable keybinds" })
hl.bind(mod .. " + SHIFT + A",      function() user.rofi.animations() end,            { desc = "Animation selector" })
hl.bind(mod .. " + ALT + C",        function() user.rofi.calc() end,                  { desc = "Calculator" })

-- Keyboard layout switching
hl.bind("ALT_L + SHIFT_L", function() user.input.switch_layout() end, { locked = true, non_consuming = true, desc = "Switch keyboard layout" })

-- Move current workspace to monitor
hl.bind("CTRL + ALT + left",  hl.dsp.workspace.move({ monitor = "l" }), { desc = "Move workspace to left monitor" })
hl.bind("CTRL + ALT + right", hl.dsp.workspace.move({ monitor = "r" }), { desc = "Move workspace to right monitor" })
