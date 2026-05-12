---
-- Display Control Functions
-- Provides screen brightness, keyboard backlight, night light, and blur control
--
-- All functions automatically show notifications and use baked-in increments
--
-- @module user-functions.display
-- @author Brett
-- @license MIT

local display = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local ICON_DIR = os.getenv("HOME") .. "/.config/swaync/icons"
local IMAGE_DIR = os.getenv("HOME") .. "/.config/swaync/images"
local CACHE_DIR = os.getenv("HOME") .. "/.cache"
local STATE_FILE = CACHE_DIR .. "/.hyprsunset_state"

local ICONS = {
    brightness = {
        [20] = ICON_DIR .. "/brightness-20.png",
        [40] = ICON_DIR .. "/brightness-40.png",
        [60] = ICON_DIR .. "/brightness-60.png",
        [80] = ICON_DIR .. "/brightness-80.png",
        [100] = ICON_DIR .. "/brightness-100.png"
    },
    blur = {
        normal = IMAGE_DIR .. "/ja.png",
        less = IMAGE_DIR .. "/note.png"
    }
}

local NIGHTLIGHT_TEMP = 4500

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Get the current screen brightness using brightnessctl
-- @return number|nil The current brightness level (0-100), or nil on error
-- @return string|nil Error message if command failed
local function get_brightness()
    local result = helpers.exec("brightnessctl -m | cut -d, -f4 | tr -d '%'")

    if not result.success then
        return nil, result.stderr or "Failed to get brightness"
    end

    local brightness = tonumber(result.stdout:match("%d+"))

    return brightness
end

---Get the current keyboard backlight brightness
-- @return number|nil The current keyboard brightness level (0-100), or nil on error
-- @return string|nil Error message if command failed
local function get_kbd_brightness()
    local result = helpers.exec("brightnessctl -d '*::kbd_backlight' -m | cut -d, -f4 | tr -d '%'")

    if not result.success then
        return nil, result.stderr or "Failed to get keyboard brightness"
    end

    local brightness = tonumber(result.stdout:match("%d+"))

    return brightness
end

---Get the appropriate brightness icon based on brightness level
-- Rounds up to the nearest 20, capped at 100
-- @param brightness number The current brightness level
-- @return string The path to the appropriate icon
local function get_brightness_icon(brightness)
    local level = math.ceil(brightness / 20) * 20

    if level > 100 then
        level = 100
    end

    return ICONS.brightness[level] or ICONS.brightness[100]
end

---Ensure the hyprsunset state file exists
-- Creates the state file with "off" if it doesn't exist. mkdir -p stays as a
-- shell call because Lua has no portable mkdir; it's harmless if it races.
local function ensure_state_file()
    if not helpers.path_exists(STATE_FILE) then
        hl.exec_cmd(string.format("mkdir -p %s", CACHE_DIR))
        helpers.write_file(STATE_FILE, "off")
    end
end

---Read the current hyprsunset state
-- @return string The current state ("on" or "off")
local function read_state()
    ensure_state_file()

    local data = helpers.read_file(STATE_FILE)
    if not data then
        return "off"
    end

    local state = data:gsub("%s+$", "")
    return state == "on" and "on" or "off"
end

---Write the hyprsunset state
-- @param state string The state to write ("on" or "off")
local function write_state(state)
    helpers.write_file(STATE_FILE, state)
end

---Check if hyprsunset is currently running
-- @return boolean True if hyprsunset process exists
local function is_hyprsunset_running()
    local result = helpers.exec("pgrep -x hyprsunset >/dev/null 2>&1 && echo 'running' || echo 'stopped'")

    return result.success and result.stdout:match("running") ~= nil
end

---Kill any running hyprsunset process
local function stop_hyprsunset()
    hl.exec_cmd("pkill -x hyprsunset 2>/dev/null || true")
    helpers.sleep(0.2)
end

---Get the current blur passes setting
-- @return number|nil The current blur passes, or nil on error
-- @return string|nil Error message if command failed
local function get_blur_passes()
    local success, passes = pcall(function()
        return hl.config.decoration.blur.passes
    end)

    if not success then
        return nil, "Failed to get blur passes"
    end

    return passes
end

-- ============================================
-- NOTIFICATION HELPERS
-- ============================================

---Send a screen brightness notification
-- @param brightness number The current brightness level
local function notify_brightness(brightness)
    local icon = get_brightness_icon(brightness)

    notify.send({
        text = string.format("Brightness: %d%%", brightness),
        icon = icon,
        timeout = 2000
    })
end

---Send a keyboard brightness notification
-- @param brightness number The current keyboard brightness level
local function notify_kbd_brightness(brightness)
    local icon = get_brightness_icon(brightness)

    notify.send({
        text = string.format("Keyboard: %d%%", brightness),
        icon = icon,
        timeout = 2000
    })
end

---Send a night light notification
-- @param enabled boolean Whether night light is enabled
-- @param temp number|nil The color temperature in Kelvin
local function notify_nightlight(enabled, temp)
    local notify = require("utils.notify")

    if enabled then
        notify.info(string.format("Night light enabled @ %dK", temp or NIGHTLIGHT_TEMP))
    else
        notify.info("Night light disabled")
    end
end

---Send a blur toggle notification
-- @param normal boolean True if normal blur, false if less blur
local function notify_blur(normal)
    local icon = normal and ICONS.blur.normal or ICONS.blur.less
    local text = normal and "Normal Blur" or "Less Blur"

    notify.send({
        text = text,
        icon = icon,
        timeout = 2000
    })
end

-- ============================================
-- SCREEN BRIGHTNESS CONTROL
-- ============================================

---Increase screen brightness by 5%
-- Automatically clamps to maximum of 100%
-- Shows a notification with the new brightness level and appropriate icon
-- @function brightness_up
function display.brightness_up()
    local success, err = pcall(function()
        local current = get_brightness()

        if current == nil then
            local notify = require("utils.notify")
            notify.error("Failed to get current brightness")

            return
        end

        local new_brightness = current + 5

        if new_brightness > 100 then
            new_brightness = 100
        end

        local result = helpers.exec(string.format("brightnessctl set %d%%", new_brightness))

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to increase brightness", result.stderr)

            return
        end

        notify_brightness(new_brightness)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Brightness up failed", tostring(err))
    end
end

---Decrease screen brightness by 5%
-- Automatically clamps to minimum of 5%
-- Shows a notification with the new brightness level and appropriate icon
-- @function brightness_down
function display.brightness_down()
    local success, err = pcall(function()
        local current = get_brightness()

        if current == nil then
            local notify = require("utils.notify")
            notify.error("Failed to get current brightness")

            return
        end

        local new_brightness = current - 5

        if new_brightness < 5 then
            new_brightness = 5
        end

        local result = helpers.exec(string.format("brightnessctl set %d%%", new_brightness))

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to decrease brightness", result.stderr)

            return
        end

        notify_brightness(new_brightness)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Brightness down failed", tostring(err))
    end
end

-- ============================================
-- KEYBOARD BRIGHTNESS CONTROL
-- ============================================

---Increase keyboard brightness by 30%
-- Shows a notification with the new brightness level and appropriate icon
-- @function kbd_brightness_up
function display.kbd_brightness_up()
    local success, err = pcall(function()
        local current = get_kbd_brightness()

        if current == nil then
            local notify = require("utils.notify")
            notify.error("Failed to get keyboard brightness")

            return
        end

        local result = helpers.exec("brightnessctl -d '*::kbd_backlight' set +30%")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to increase keyboard brightness", result.stderr)

            return
        end

        local new_brightness = get_kbd_brightness() or current

        notify_kbd_brightness(new_brightness)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Keyboard brightness up failed", tostring(err))
    end
end

---Decrease keyboard brightness by 30%
-- Shows a notification with the new brightness level and appropriate icon
-- @function kbd_brightness_down
function display.kbd_brightness_down()
    local success, err = pcall(function()
        local current = get_kbd_brightness()

        if current == nil then
            local notify = require("utils.notify")
            notify.error("Failed to get keyboard brightness")

            return
        end

        local result = helpers.exec("brightnessctl -d '*::kbd_backlight' set 30%-")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to decrease keyboard brightness", result.stderr)

            return
        end

        local new_brightness = get_kbd_brightness() or current

        notify_kbd_brightness(new_brightness)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Keyboard brightness down failed", tostring(err))
    end
end

-- ============================================
-- NIGHT LIGHT CONTROL
-- ============================================

---Toggle hyprsunset (night light) on/off
-- When turning on, starts hyprsunset at 4500K
-- When turning off, applies identity and stops hyprsunset
-- Shows a notification indicating the new state
-- @function nightlight_toggle
function display.nightlight_toggle()
    local success, err = pcall(function()
        local current_state = read_state()
        local running = is_hyprsunset_running()

        stop_hyprsunset()

        if (current_state == "on") or running then
            local result = helpers.exec("hyprsunset -i")
            helpers.sleep(0.3)
            stop_hyprsunset()
            write_state("off")
            notify_nightlight(false)
        else
            hl.exec_cmd(string.format("nohup hyprsunset -t %d >/dev/null 2>&1 &", NIGHTLIGHT_TEMP))
            write_state("on")
            notify_nightlight(true, NIGHTLIGHT_TEMP)
        end
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Night light toggle failed", tostring(err))
    end
end

---Get the night light status as JSON for Waybar integration
-- Returns a JSON object with text (icon), class (on/off), and tooltip
-- @return string JSON formatted status
-- @function nightlight_status
function display.nightlight_status()
    local success, result = pcall(function()
        ensure_state_file()

        local running = is_hyprsunset_running()
        local state = read_state()

        if running then
            state = "on"
        end

        local text, class, tooltip

        if state == "on" then
            text = "🌇"
            class = "on"
            tooltip = string.format("Night light on @ %dK", NIGHTLIGHT_TEMP)
        else
            text = "☀"
            class = "off"
            tooltip = "Night light off"
        end

        local json = string.format(
            '{"text":"%s","class":"%s","tooltip":"%s"}',
            text,
            class,
            tooltip
        )

        return json
    end)

    if not success then
        return '{"text":"☀","class":"off","tooltip":"Night light off"}'
    end

    return result
end

-- ============================================
-- BLUR TOGGLE CONTROL
-- ============================================

---Toggle blur passes between normal and less
-- Normal: passes=2, size=5
-- Less: passes=1, size=2
-- Shows a notification with the new blur state
-- @function blur_toggle
function display.blur_toggle()
    local success, err = pcall(function()
        local current_passes = get_blur_passes()

        if current_passes == nil then
            local notify = require("utils.notify")
            notify.error("Failed to get blur setting")

            return
        end

        if current_passes == 2 then
            local success = pcall(function()
                hl.config.decoration.blur.size = 2
                hl.config.decoration.blur.passes = 1
            end)

            if not success then
                local notify = require("utils.notify")
                notify.error("Failed to set less blur")

                return
            end

            notify_blur(false)
        else
            local success = pcall(function()
                hl.config.decoration.blur.size = 5
                hl.config.decoration.blur.passes = 2
            end)

            if not success then
                local notify = require("utils.notify")
                notify.error("Failed to set normal blur")

                return
            end

            notify_blur(true)
        end
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Blur toggle failed", tostring(err))
    end
end

return display
