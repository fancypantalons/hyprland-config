-- Keybindings
-- Based on configs/Keybinds.conf, UserConfigs/Laptops.conf, and UserConfigs/UserKeybinds.conf

local mod = "SUPER"
local scriptsDir = configDir .. "/scripts"

-- Default applications live in user-functions/system.lua (TERMINAL / FILE_MANAGER)

-- ============================================
-- CORE BINDS (from configs/Keybinds.conf)
-- ============================================

-- Session management
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", function() user.window.kill_active() end)
hl.bind("CTRL + ALT + L", function() user.session.lock() end)
hl.bind("CTRL + ALT + P", function() user.session.logout() end)

-- Notifications and settings
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd(scriptsDir .. "/Kool_Quick_Settings.sh"))

-- Master Layout (only works when layout=master)
hl.bind(mod .. " + CTRL + D", hl.dsp.layout("removemaster"))
hl.bind(mod .. " + I", hl.dsp.layout("addmaster"))
hl.bind(mod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster master"))

-- Window cycling (works in any layout). Note: SUPER+K is taken by the
-- keepassxc special-workspace toggle further down — only J cycles here.
hl.bind(mod .. " + J", hl.dsp.window.cycle_next())

-- Dwindle Layout
hl.bind(mod .. " + P", hl.dsp.window.pseudo())

-- Layout resize (dwindle's splitratio layoutmsg)
hl.bind(mod .. " + M", hl.dsp.layout("splitratio 0.3"))

-- Group management
hl.bind(mod .. " + G", hl.dsp.group.toggle())
hl.bind(mod .. " + CTRL + Tab", hl.dsp.group.next())

-- Window cycling
hl.bind("ALT + Tab", function()
  hl.dispatch(hl.dsp.window.cycle_next())
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

-- Media controls (locked + repeating)
hl.bind("XF86AudioRaiseVolume", function() user.audio.volume_up() end, { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", function() user.audio.volume_down() end, { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", function() user.audio.mic_toggle() end, { locked = true })
hl.bind("XF86AudioMute", function() user.audio.volume_toggle() end, { locked = true })
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })
hl.bind("XF86Rfkill", function() user.system.airplane_mode() end, { locked = true })

-- Media playback controls
hl.bind("XF86AudioPlay", function() user.audio.media_play() end, { locked = true })
hl.bind("XF86AudioPause", function() user.audio.media_play() end, { locked = true })
hl.bind("XF86AudioNext", function() user.audio.media_next() end, { locked = true })
hl.bind("XF86AudioPrev", function() user.audio.media_prev() end, { locked = true })
hl.bind("XF86AudioStop", function() user.audio.media_stop() end, { locked = true })

-- Screenshots
hl.bind(mod .. " + Print", function() user.session.screenshot("now") end)
hl.bind(mod .. " + SHIFT + Print", function() user.session.screenshot("area") end)
hl.bind(mod .. " + CTRL + Print", function() user.session.screenshot("5") end)
hl.bind(mod .. " + CTRL + SHIFT + Print", function() user.session.screenshot("10") end)
hl.bind("ALT + Print", function() user.session.screenshot("window") end)
hl.bind(mod .. " + SHIFT + S", function() user.session.screenshot("swappy") end)

-- Resize windows (repeating)
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.resize({ x = -50, y = 0 }), { repeating = true })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50, y = 0 }), { repeating = true })
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -50 }), { repeating = true })
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 50 }), { repeating = true })

-- Move windows
hl.bind(mod .. " + CTRL + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.move({ direction = "d" }))

-- Swap windows
hl.bind(mod .. " + ALT + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mod .. " + ALT + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mod .. " + ALT + down", hl.dsp.window.swap({ direction = "d" }))

-- Focus movement
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspace navigation
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

-- Special workspace
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mod .. " + U", hl.dsp.workspace.toggle_special())

-- Workspace binds (1-10) using loops
for i = 1, 9 do
  local key = tostring(i)
  hl.bind(mod .. " + code:" .. tostring(9 + i), hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + code:" .. tostring(9 + i), hl.dsp.window.move({ workspace = i }))
  hl.bind(mod .. " + CTRL + code:" .. tostring(9 + i), hl.dsp.window.move({ workspace = i, silent = true }))
end

hl.bind(mod .. " + code:19", hl.dsp.focus({ workspace = 10 }))  -- code:19 = key 0
hl.bind(mod .. " + SHIFT + code:19", hl.dsp.window.move({ workspace = 10 }))
hl.bind(mod .. " + CTRL + code:19", hl.dsp.window.move({ workspace = 10, silent = true }))

-- Move to workspace with bracket keys
hl.bind(mod .. " + SHIFT + bracketleft", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mod .. " + CTRL + bracketleft", hl.dsp.window.move({ workspace = "-1", silent = true }))
hl.bind(mod .. " + CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", silent = true }))

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ============================================
-- LAPTOP BINDS (from UserConfigs/Laptops.conf)
-- ============================================

hl.bind("XF86KbdBrightnessDown", function() user.display.kbd_brightness_down() end, { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp", function() user.display.kbd_brightness_up() end, { locked = true, repeating = true })
hl.bind("XF86Launch1", hl.dsp.exec_cmd("rog-control-center"))
hl.bind("XF86Launch3", hl.dsp.exec_cmd("asusctl led-mode -n"))
hl.bind("XF86Launch4", hl.dsp.exec_cmd("asusctl profile -n"))
hl.bind("XF86MonBrightnessDown", function() user.display.brightness_down() end, { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", function() user.display.brightness_up() end, { locked = true, repeating = true })
hl.bind("XF86TouchpadToggle", function() user.system.touchpad_toggle() end)

-- Screenshot alternatives for laptops without Print key
hl.bind(mod .. " + F11", function() user.session.screenshot("now") end)
hl.bind(mod .. " + SHIFT + F11", function() user.session.screenshot("area") end)
hl.bind(mod .. " + CTRL + F11", function() user.session.screenshot("window") end)

-- ============================================
-- USER BINDS (from UserConfigs/UserKeybinds.conf)
-- ============================================

hl.bind("F12", hl.dsp.exec_cmd("kitten quick-access-terminal"))
hl.bind(mod .. " + F12", hl.dsp.exec_cmd("kitten quick-access-terminal"), { locked = true })

-- Application launchers
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd('xdg-open "https://"'))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("pkill rofi || true && ags -t 'overview'"))
hl.bind(mod .. " + Return", function() user.system.terminal() end)
hl.bind(mod .. " + E", function() user.system.file_manager() end)

-- Special applications
hl.bind(mod .. " + S", function()
  local handle = io.popen("pgrep signal")
  local result = handle:read("*a")
  handle:close()

  if (result ~= "") then
    hl.dispatch(hl.dsp.workspace.toggle_special("signal"))
  else
    hl.dispatch(hl.dsp.exec_cmd("gtk-launch org.signal.Signal"))
  end
end)
hl.bind(mod .. " + K", hl.dsp.workspace.toggle_special("keepassxc"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd(scriptsDir .. "/DevTools.rb"))

-- Features and extras
hl.bind(mod .. " + H", function() user.session.show_hints() end)
hl.bind(mod .. " + ALT + R", function()
    local refresh = require("utils.refresh")
    refresh.refresh_ui()
end)
hl.bind(mod .. " + ALT + E", function() user.rofi.emoji() end)
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mod .. " + ALT + O", function() user.display.blur_toggle() end)
hl.bind(mod .. " + SHIFT + G", function() user.window.game_mode() end)
hl.bind(mod .. " + ALT + L", function() user.window.layout_toggle() end)
hl.bind(mod .. " + ALT + V", function() user.system.clipboard_manager() end)
hl.bind(mod .. " + CTRL + R", function() user.rofi.theme_selector() end)
hl.bind(mod .. " + CTRL + SHIFT + R", function() user.rofi.theme_selector() end)

-- Window management
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mod .. " + F", hl.dsp.window.float())
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"))

-- Desktop zoom/magnifier — read current factor, double/halve, write back.
-- The clamp-up-to-1 mirrors the original shell math: zoom out from 0.5 should
-- still treat the floor as 1, otherwise we never re-engage the magnifier.
local function zoom(scale)
  return function()
    local f = tonumber(hl.get_config("cursor.zoom_factor")) or 1
    if f < 1 then f = 1 end
    hl.config.cursor.zoom_factor = f * scale
  end
end

hl.bind(mod .. " + ALT + mouse_down", zoom(2.0))
hl.bind(mod .. " + ALT + mouse_up", zoom(0.5))

-- Waybar controls
hl.bind(mod .. " + CTRL + ALT + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(mod .. " + CTRL + B", function() user.waybar.select_style() end)
hl.bind(mod .. " + ALT + B", function() user.waybar.select_layout() end)

-- Night light (Hyprsunset)
hl.bind(mod .. " + N", function() user.display.nightlight_toggle() end)

-- Scripts features
hl.bind(mod .. " + SHIFT + M", function() user.rofi.beats() end)
hl.bind(mod .. " + W", function() user.wallpaper.select() end)
hl.bind(mod .. " + SHIFT + W", function() user.wallpaper.effects() end)
hl.bind("CTRL + ALT + W", function() user.wallpaper.random() end)
hl.bind(mod .. " + CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }))
hl.bind(mod .. " + SHIFT + K", function() user.session.show_binds() end)
hl.bind(mod .. " + SHIFT + A", function() user.rofi.animations() end)
-- ZshChangeTheme.sh removed - not used
hl.bind(mod .. " + ALT + C", function() user.rofi.calc() end)

-- Keyboard layout switching
hl.bind("ALT_L + SHIFT_L", function() user.input.switch_layout() end, { locked = true, non_consuming = true })

-- Move current workspace to monitor
hl.bind("CTRL + ALT + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind("CTRL + ALT + right", hl.dsp.workspace.move({ monitor = "r" }))
