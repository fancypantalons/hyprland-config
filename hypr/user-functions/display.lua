-- Display control: screen brightness, keyboard backlight, night light, blur toggle.

local display = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local proc    = require("utils.proc")
local state   = require("utils.state")

local NIGHTLIGHT_TEMP = 4500

-- ============================================
-- INTERNAL HELPERS
-- ============================================

local function get_brightness()
    -- brightnessctl -m: device,type,value,percent%,max
    return tonumber(helpers.exec("brightnessctl -m").stdout:match(",(%d+)%%,"))
end

local function get_kbd_brightness()
    return tonumber(helpers.exec("brightnessctl -d '*::kbd_backlight' -m").stdout:match(",(%d+)%%,"))
end

local function adjust_brightness(delta)
    local cur = get_brightness()
    if cur == nil then notify.error("Failed to get brightness"); return end
    local new_val = math.max(5, math.min(100, cur + delta))
    helpers.exec(string.format("brightnessctl set %d%%", new_val))
    notify.brightness(new_val)
end

local function adjust_kbd_brightness(arg)
    helpers.exec("brightnessctl -d '*::kbd_backlight' set " .. arg)
    notify.kbd_brightness(get_kbd_brightness() or 0)
end

-- ============================================
-- SCREEN BRIGHTNESS
-- ============================================

function display.brightness_up()
    helpers.safe_call("Brightness up failed", function() adjust_brightness(5) end)
end

function display.brightness_down()
    helpers.safe_call("Brightness down failed", function() adjust_brightness(-5) end)
end

-- ============================================
-- KEYBOARD BACKLIGHT
-- ============================================

function display.kbd_brightness_up()
    helpers.safe_call("Keyboard brightness up failed", function() adjust_kbd_brightness("+30%") end)
end

function display.kbd_brightness_down()
    helpers.safe_call("Keyboard brightness down failed", function() adjust_kbd_brightness("30%-") end)
end

-- ============================================
-- NIGHT LIGHT (hyprsunset)
-- ============================================

local function hyprsunset_on()
    return proc.running("hyprsunset")
end

function display.nightlight_toggle()
    helpers.safe_call("Night light toggle failed", function()
        local was_on = (state.get("nightlight", "off") == "on") or hyprsunset_on()

        proc.kill("hyprsunset")

        if was_on then
            helpers.exec_async("hyprsunset -i", function(_, _)
                proc.kill("hyprsunset")
                state.set("nightlight", "off")
                notify.nightlight(false)
            end)
        else
            hl.exec_cmd(string.format("nohup hyprsunset -t %d >/dev/null 2>&1 &", NIGHTLIGHT_TEMP))
            state.set("nightlight", "on")
            notify.nightlight(true, NIGHTLIGHT_TEMP)
        end
    end)
end

---Return Waybar-compatible JSON for the night-light module.
function display.nightlight_status()
    return helpers.safe_call("Night light status failed", function()
        local on = hyprsunset_on() or (state.get("nightlight", "off") == "on")
        if on then state.set("nightlight", "on") end
        return on
            and string.format('{"text":"🌇","class":"on","tooltip":"Night light on @ %dK"}', NIGHTLIGHT_TEMP)
            or  '{"text":"☀","class":"off","tooltip":"Night light off"}'
    end, '{"text":"☀","class":"off","tooltip":"Night light off"}')
end

-- ============================================
-- BLUR TOGGLE
-- ============================================

function display.blur_toggle()
    helpers.safe_call("Blur toggle failed", function()
        local cur = hl.config.decoration.blur.passes
        if cur == nil then notify.error("Failed to get blur setting"); return end

        if cur == 2 then
            hl.config.decoration.blur.size   = 2
            hl.config.decoration.blur.passes = 1
            notify.blur(false)
        else
            hl.config.decoration.blur.size   = 5
            hl.config.decoration.blur.passes = 2
            notify.blur(true)
        end
    end)
end

return display
