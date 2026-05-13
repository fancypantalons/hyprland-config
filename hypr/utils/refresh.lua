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
    return helpers.path_exists(path)
end

-- ============================================
-- REFRESH FUNCTIONS
-- ============================================

---Full refresh of the UI
-- Kills rofi, restarts ags, runs wallust, reloads swaync, restarts waybar.
-- Optional cb is called after all steps complete.
-- @param cb function|nil Optional completion callback
-- @function refresh_ui
function refresh.refresh_ui(cb)
    local notify = require("utils.notify")

    for _, proc in ipairs({"waybar", "rofi", "swaync", "ags"}) do
        kill_process(proc)
    end

    hl.exec_cmd("killall -SIGUSR2 waybar 2>/dev/null || true")

    helpers.exec_async("ags -q 2>/dev/null || true; sleep 0.1", function(_, _)
        pcall(function()
            hl.exec_cmd("ags &")

            local signal_procs = { "waybar", "rofi", "swaync", "ags", "swaybg" }

            for _, proc in ipairs(signal_procs) do
                if is_running(proc) then
                    signal_usr1(proc)
                end
            end

            helpers.exec_async("sleep 1", function(_, _)
                pcall(function()
                    hl.exec_cmd("waybar &")

                    helpers.exec_async("sleep 0.5", function(_, _)
                        pcall(function()
                            hl.exec_cmd("swaync > /dev/null 2>&1 &")

                            helpers.exec_async("sleep 0.2", function(_, _)
                                pcall(function()
                                    hl.exec_cmd("swaync-client --reload-config")

                                    helpers.exec_async("sleep 1", function(_, _)
                                        pcall(function()
                                            if file_exists(USERSCRIPTS .. "/RainbowBorders.sh") then
                                                hl.exec_cmd(USERSCRIPTS .. "/RainbowBorders.sh &")
                                            end

                                            if cb then
                                                cb()
                                            end
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

---Refresh UI without restarting waybar
-- Same as refresh_ui but skips waybar restart. Optional cb called on completion.
-- @param cb function|nil Optional completion callback
-- @function refresh_ui_no_waybar
function refresh.refresh_ui_no_waybar(cb)
    kill_process("rofi")

    helpers.exec_async("ags -q 2>/dev/null || true; sleep 0.1", function(_, _)
        pcall(function()
            hl.exec_cmd("ags &")

            local wallpaper = require("user-functions.wallpaper")
            wallpaper.apply_wallust()

            helpers.exec_async("sleep 0.2", function(_, _)
                pcall(function()
                    hl.exec_cmd("swaync-client --reload-config")

                    helpers.exec_async("sleep 1", function(_, _)
                        pcall(function()
                            if file_exists(USERSCRIPTS .. "/RainbowBorders.sh") then
                                hl.exec_cmd(USERSCRIPTS .. "/RainbowBorders.sh &")
                            end

                            if cb then
                                cb()
                            end
                        end)
                    end)
                end)
            end)
        end)
    end)
end

return refresh
