---
-- Internal Refresh Utilities
-- Internal refresh utilities (not user-facing)
-- Handles killing processes, restarting services, and refreshing the UI
--
-- @module utils.refresh
-- @author Brett
-- @license MIT

local refresh = {}
local helpers = require("utils.helpers")

-- ============================================
-- CONFIGURATION
-- ============================================

local HOME = os.getenv("HOME")
local SCRIPTSDIR = HOME .. "/.config/hypr/scripts"
local USERSCRIPTS = HOME .. "/.config/hypr/scripts"

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Check if a command exists
-- @param cmd string The command to check
-- @return boolean True if the command exists
local function command_exists(cmd)
    local result = helpers.exec("command -v " .. cmd .. " 2>/dev/null")

    return result.success and result.stdout ~= ""
end

---Kill a process by name if it's running
-- @param process string The process name to kill
local function kill_process(process)
    hl.exec_cmd("pkill " .. process .. " 2>/dev/null || true")
end

---Check if a process is running
-- @param process string The process name to check
-- @return boolean True if the process is running
local function is_running(process)
    local result = helpers.exec("pidof " .. process .. " 2>/dev/null")

    return result.success and result.stdout ~= ""
end

---Send SIGUSR1 signal to a process
-- @param process string The process name
local function signal_usr1(process)
    hl.exec_cmd("killall -SIGUSR1 " .. process .. " 2>/dev/null || true")
end

---Check if a file exists
-- @param path string The file path to check
-- @return boolean True if the file exists
local function file_exists(path)
    local result = helpers.exec("test -f '" .. path .. "' 2>/dev/null")

    return result.success
end

-- ============================================
-- REFRESH FUNCTIONS
-- ============================================

---Full refresh of the UI
-- Kills rofi, restarts ags, runs wallust, reloads swaync, restarts waybar
-- @function refresh_ui
function refresh.refresh_ui()
    local notify = require("utils.notify")

    local success, err = pcall(function()
        -- Kill already running processes
        local processes = { "waybar", "rofi", "swaync", "ags" }

        for _, proc in ipairs(processes) do
            kill_process(proc)
        end

        -- Added since wallust sometimes not applying
        hl.exec_cmd("killall -SIGUSR2 waybar 2>/dev/null || true")

        -- Quit ags and relaunch
        hl.exec_cmd("ags -q 2>/dev/null || true")
        helpers.sleep(0.1)
        hl.exec_cmd("ags &")

        -- Send SIGUSR1 to various processes
        local signal_procs = { "waybar", "rofi", "swaync", "ags", "swaybg" }

        for _, proc in ipairs(signal_procs) do
            if is_running(proc) then
                signal_usr1(proc)
            end
        end

        -- Restart waybar
        helpers.sleep(1)
        hl.exec_cmd("waybar &")

        -- Relaunch swaync
        helpers.sleep(0.5)
        hl.exec_cmd("swaync > /dev/null 2>&1 &")
        helpers.sleep(0.2)
        hl.exec_cmd("swaync-client --reload-config")

        -- Relaunching rainbow borders if the script exists
        helpers.sleep(1)

        if file_exists(USERSCRIPTS .. "/RainbowBorders.sh") then
            hl.exec_cmd(USERSCRIPTS .. "/RainbowBorders.sh &")
        end
    end)

    if not success then
        notify.error("Refresh failed", tostring(err))
    end
end

---Refresh UI without restarting waybar
-- Same as refresh_ui but skips waybar restart
-- Used by automatic wallpaper change
-- @function refresh_ui_no_waybar
function refresh.refresh_ui_no_waybar()
    local notify = require("utils.notify")

    local success, err = pcall(function()
        -- Kill rofi if running
        kill_process("rofi")

        -- Quit ags and relaunch
        hl.exec_cmd("ags -q 2>/dev/null || true")
        helpers.sleep(0.1)
        hl.exec_cmd("ags &")

        -- Regenerate wallust colors from the current wallpaper
        local wallpaper = require("user-functions.wallpaper")
        wallpaper.apply_wallust()
        helpers.sleep(0.2)

        -- Reload swaync
        hl.exec_cmd("swaync-client --reload-config")

        -- Relaunching rainbow borders if the script exists
        helpers.sleep(1)

        if file_exists(USERSCRIPTS .. "/RainbowBorders.sh") then
            hl.exec_cmd(USERSCRIPTS .. "/RainbowBorders.sh &")
        end
    end)

    if not success then
        notify.error("Refresh (no waybar) failed", tostring(err))
    end
end

return refresh
