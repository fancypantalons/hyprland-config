---
-- System Control Functions
-- Provides airplane mode, touchpad toggle, clipboard manager, idle inhibitor,
-- polkit agent startup, and dropdown terminal functionality
--
-- @module user-functions.system
-- @author Brett
-- @license MIT

local system = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local ICON_FILE = os.getenv("HOME") .. "/.config/swaync/images/ja.png"

local CLIPBOARD_ROFI_THEME = os.getenv("HOME") .. "/.config/rofi/config-clipboard.rasi"

local TERMINAL = "kitty"
local FILE_MANAGER = "thunar"

local STATUS_FILE = os.getenv("XDG_RUNTIME_DIR") .. "/touchpad.status"

local DROPDOWN_ADDR_FILE = "/tmp/dropdown_terminal_addr"

local SPECIAL_WORKSPACE = "special:scratchpad"

local DROPDOWN_CONFIG = {
    width_percent = 50,
    height_percent = 50,
    y_percent = 5
}

local POLKIT_AGENTS = {
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
    "/usr/libexec/hyprpolkitagent",
    "/usr/lib/hyprpolkitagent",
    "/usr/lib/hyprpolkitagent/hyprpolkitagent",
    "/usr/lib/polkit-kde-authentication-agent-1",
    "/usr/lib/polkit-gnome-authentication-agent-1",
    "/usr/libexec/polkit-gnome-authentication-agent-1",
    "/usr/libexec/polkit-mate-authentication-agent-1",
    "/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1",
    "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Send a system notification with the default icon
---@param title string The notification title
---@param message string The notification message
local function notify_system(title, message)
    notify.send({
        text = title .. ": " .. message,
        icon = ICON_FILE,
        timeout = 2000
    })
end

---Send an error notification
---@param message string The error message
---@param details string|nil Optional error details
local function notify_error(message, details)
    local notify = require("utils.notify")

    notify.error(message, details)
end

-- ============================================
-- AIRPLANE MODE
-- ============================================

---Toggle airplane mode (WiFi on/off) using rfkill
-- Checks the current WiFi state and toggles it
-- Shows a notification with the new state
-- @function airplane_mode
function system.airplane_mode()
    local success, err = pcall(function()
        local result = helpers.exec("rfkill list wifi | grep 'Soft blocked: yes'")
        local is_blocked = result.success and result.stdout ~= ""
        local toggle_result

        if is_blocked then
            toggle_result = helpers.exec("rfkill unblock wifi")

            if toggle_result.success then
                notify_system("Airplane Mode", "OFF")
            else
                notify_error("Failed to disable airplane mode", toggle_result.stderr)

                return
            end
        else
            toggle_result = helpers.exec("rfkill block wifi")

            if toggle_result.success then
                notify_system("Airplane Mode", "ON")
            else
                notify_error("Failed to enable airplane mode", toggle_result.stderr)

                return
            end
        end
    end)

    if not success then
        notify_error("Airplane mode toggle failed", tostring(err))
    end
end

-- ============================================
-- TOUCHPAD TOGGLE
-- ============================================

---Enable the touchpad
-- Sets the TOUCHPAD_ENABLED variable to true and saves state
local function touchpad_enable()
    if not helpers.write_file(STATUS_FILE, "true") then
        notify_error("Failed to save touchpad state")
        return false
    end

    hl.device({ name = "asue1209:00-04f3:319f-touchpad", enabled = true })
    notify_system("Touchpad", "Enabled")

    return true
end

---Disable the touchpad
-- Sets the TOUCHPAD_ENABLED variable to false and saves state
local function touchpad_disable()
    if not helpers.write_file(STATUS_FILE, "false") then
        notify_error("Failed to save touchpad state")
        return false
    end

    hl.device({ name = "asue1209:00-04f3:319f-touchpad", enabled = false })
    notify_system("Touchpad", "Disabled")

    return true
end

---Toggle the touchpad on/off
-- Uses the status file to track current state
-- Shows a notification with the new state
-- @function touchpad_toggle
function system.touchpad_toggle()
    local success, err = pcall(function()
        local current = helpers.read_file(STATUS_FILE)

        if not current then
            touchpad_enable()
            return
        end

        local status = current:gsub("%s+$", "")

        if status == "true" then
            touchpad_disable()
        else
            touchpad_enable()
        end
    end)

    if not success then
        notify_error("Touchpad toggle failed", tostring(err))
    end
end

-- ============================================
-- CLIPBOARD MANAGER
-- ============================================

---Open the clipboard manager using cliphist and rofi
-- Shows clipboard history in a rofi menu
-- Supports Ctrl+Delete to delete a single entry
-- Supports Alt+Delete to wipe all clipboard history
-- @function clipboard_manager
function system.clipboard_manager()
    local success, err = pcall(function()
        -- Kill any existing rofi process
        hl.exec_cmd("pkill rofi 2>/dev/null")

        local msg = "CTRL+DEL = Delete entry | ALT+DEL = Wipe all"

        -- Run cliphist list and pipe to rofi
        local cliphist_result = helpers.exec("cliphist list")

        if not cliphist_result.success then
            notify_error("Failed to get clipboard history", "Is cliphist installed?")

            return
        end

        local clipboard_entries = cliphist_result.stdout

        if clipboard_entries == "" then
            notify_system("Clipboard", "No entries in history")

            return
        end

        -- Run rofi with the clipboard entries
        -- Note: We use a shell command to pipe cliphist output to rofi
        local rofi_cmd = string.format(
            "echo '%s' | rofi -i -dmenu -kb-custom-1 'Control-Delete' -kb-custom-2 'Alt-Delete' -config '%s' -mesg '%s'",
            clipboard_entries:gsub("'", "'\"'\"'"),
            CLIPBOARD_ROFI_THEME,
            msg
        )

        local rofi_result = helpers.exec(rofi_cmd)
        local exit_code = rofi_result.exit_code or 0
        local selection = rofi_result.stdout and rofi_result.stdout:gsub("%s+$", "") or ""

        -- Exit code 1 = user cancelled
        if exit_code == 1 then
            return
        end

        -- Exit code 0 = user selected an entry
        if exit_code == 0 then
            if selection == "" then
                return
            end

            -- Decode the selection and copy to clipboard
            local decode_cmd = string.format("echo '%s' | cliphist decode | wl-copy", selection:gsub("'", "'\"'\"'"))
            local decode_result = helpers.exec(decode_cmd)

            if not decode_result.success then
                notify_error("Failed to copy to clipboard")
            end

        -- Exit code 10 (custom-1) = Ctrl+Delete to delete entry
        elseif exit_code == 10 then
            if selection ~= "" then
                local delete_cmd = string.format("echo '%s' | cliphist delete", selection:gsub("'", "'\"'\"'"))
                hl.exec_cmd(delete_cmd)

                notify_system("Clipboard", "Entry deleted")
            end

        -- Exit code 11 (custom-2) = Alt+Delete to wipe all
        elseif exit_code == 11 then
            hl.exec_cmd("cliphist wipe")
            notify_system("Clipboard", "History wiped")
        end
    end)

    if not success then
        notify_error("Clipboard manager failed", tostring(err))
    end
end

-- ============================================
-- IDLE INHIBITOR (HYPRIDLE)
-- ============================================

---Toggle the hypridle process on/off
-- Checks if hypridle is running and toggles its state
-- @function idle_inhibit_toggle
function system.idle_inhibit_toggle()
    local success, err = pcall(function()
        local check_result = helpers.exec("pgrep -x hypridle")
        local is_running = check_result.success

        if is_running then
            local kill_result = helpers.exec("pkill -x hypridle")

            if kill_result.success then
                notify_system("Screen auto-lock", "Disabled — screen won't lock")
            else
                notify_error("Failed to stop hypridle")
            end
        else
            local start_result = helpers.exec("hypridle")

            if start_result.success then
                notify_system("Screen auto-lock", "Enabled — screen will lock when idle")
            else
                notify_error("Failed to start hypridle")
            end
        end
    end)

    if not success then
        notify_error("Idle inhibitor toggle failed", tostring(err))
    end
end

---Get the idle inhibitor status for Waybar
-- Returns JSON formatted output for Waybar custom module
-- @return string JSON with text, class, and tooltip
-- @function idle_inhibit_status
function system.idle_inhibit_status()
    local success, result = pcall(function()
        local check_result = helpers.exec("pgrep -x hypridle")
        local is_running = check_result.success

        if is_running then
            return '{"text": "RUNNING", "class": "active", "tooltip": "Screen auto-lock: ON\nLeft Click: Disable auto-lock\nRight Click: Lock now"}'
        else
            return '{"text": "NOT RUNNING", "class": "notactive", "tooltip": "Screen auto-lock: OFF\nLeft Click: Enable auto-lock\nRight Click: Lock now"}'
        end
    end)

    if success then
        return result
    else
        return '{"text": "ERROR", "class": "error", "tooltip": "Failed to check status"}'
    end
end

-- ============================================
-- POLKIT AGENT
-- ============================================

---Start the first available polkit authentication agent
-- Checks a list of common polkit agent paths and executes the first one found
-- @function start_polkit
function system.start_polkit()
    local success, err = pcall(function()
        for _, agent_path in ipairs(POLKIT_AGENTS) do
            local check_result = helpers.exec("test -e " .. agent_path .. " && test ! -d " .. agent_path)

            if check_result.success then
                -- Execute the polkit agent
                hl.exec_cmd(agent_path)

                return
            end
        end

        notify_error("No polkit agent found", "Please install a polkit agent")
    end)

    if not success then
        notify_error("Polkit startup failed", tostring(err))
    end
end

-- ============================================
-- DROPDOWN TERMINAL
-- ============================================

---Read the dropdown state file as "address monitor".
---@return string|nil address, string|nil monitor
local function read_dropdown_state()
    local data = helpers.read_file(DROPDOWN_ADDR_FILE)
    if not data or data == "" then
        return nil, nil
    end

    local first_line = data:match("[^\r\n]+") or ""
    local addr, monitor = first_line:match("^(%S+)%s+(.+)$")
    if not addr then
        addr = first_line:match("^(%S+)") -- monitor missing; tolerate
    end

    return addr, monitor
end

---Get the stored terminal address from file
---@return string|nil The terminal address or nil if not found
local function get_dropdown_address()
    local addr = read_dropdown_state()
    return addr
end

---Get the stored terminal monitor from file
---@return string|nil The monitor name or nil if not found
local function get_dropdown_monitor()
    local _, monitor = read_dropdown_state()
    return monitor
end

---Check if the terminal window still exists
---@param addr string The terminal address
---@return boolean True if the terminal exists
local function dropdown_exists(addr)
    return hl.get_window("address:" .. addr) ~= nil
end

---Check if the terminal is in the special workspace
---@param addr string The terminal address
---@return boolean True if in special workspace
local function dropdown_in_special(addr)
    local w = hl.get_window("address:" .. addr)
    return w ~= nil and w.workspace ~= nil and w.workspace.name == SPECIAL_WORKSPACE
end

---Get focused monitor information
---@return table|nil Monitor info with x, y, width, height, scale, name
local function get_monitor_info()
    local m = hl.get_active_monitor()
    if not m then
        return nil
    end
    return {
        x = m.x or 0,
        y = m.y or 0,
        width = m.width or 1920,
        height = m.height or 1080,
        scale = m.scale or 1.0,
        name = m.name or "DP-1",
    }
end

---Calculate dropdown window position and size
---@return table Position with x, y, width, height, monitor_name
local function calculate_dropdown_position()
    local monitor = get_monitor_info()

    if not monitor then
        return {x = 100, y = 100, width = 800, height = 600, monitor_name = "unknown"}
    end

    -- Calculate logical dimensions (divide by scale)
    local logical_width = math.floor(monitor.width / monitor.scale)
    local logical_height = math.floor(monitor.height / monitor.scale)

    -- Calculate window dimensions based on percentages
    local width = math.floor(logical_width * DROPDOWN_CONFIG.width_percent / 100)
    local height = math.floor(logical_height * DROPDOWN_CONFIG.height_percent / 100)

    -- Calculate position
    local y_offset = math.floor(logical_height * DROPDOWN_CONFIG.y_percent / 100)
    local x_offset = math.floor((logical_width - width) / 2)

    -- Apply monitor offset
    local final_x = monitor.x + x_offset
    local final_y = monitor.y + y_offset

    return {
        x = final_x,
        y = final_y,
        width = width,
        height = height,
        monitor_name = monitor.name
    }
end

---Move a window to absolute pixel coordinates.
local function move_window_to(addr, x, y)
    hl.dispatch(hl.dsp.window.move({
        x = x, y = y, relative = false, window = "address:" .. addr,
    }))
end

---Resize a window to absolute pixel dimensions.
local function resize_window_to(addr, width, height)
    hl.dispatch(hl.dsp.window.resize({
        x = width, y = height, relative = false, window = "address:" .. addr,
    }))
end

---Animate the window sliding down (show)
local function animate_slide_down(addr, target_x, target_y, width, height)
    local start_y = target_y - height - 50
    local steps = 5
    local step_y = math.floor((target_y - start_y) / steps)

    move_window_to(addr, target_x, start_y)
    helpers.sleep(0.05)

    for i = 1, steps do
        move_window_to(addr, target_x, start_y + (step_y * i))
        helpers.sleep(0.03)
    end

    -- Ensure final position
    move_window_to(addr, target_x, target_y)
end

---Animate the window sliding up (hide)
local function animate_slide_up(addr, start_x, start_y, width, height)
    local end_y = start_y - height - 50
    local steps = 5
    local step_y = math.floor((start_y - end_y) / steps)

    for i = 1, steps do
        move_window_to(addr, start_x, start_y - (step_y * i))
        helpers.sleep(0.03)
    end
end

---Get window geometry
---@param addr string The terminal address
---@return table|nil Geometry with x, y, width, height
local function get_window_geometry(addr)
    local w = hl.get_window("address:" .. addr)
    if not w then
        return nil
    end
    return {
        x = w.at[1] or 0,
        y = w.at[2] or 0,
        width = w.size[1] or 800,
        height = w.size[2] or 600,
    }
end

---Find the most recently focused window's address.
local function most_recent_window_address()
    local windows = hl.get_windows()
    table.sort(windows, function(a, b)
        return (a.focus_history_id or 0) < (b.focus_history_id or 0)
    end)
    local last = windows[#windows]
    return last and last.address or nil
end

---Spawn a new dropdown terminal
---@param terminal_cmd string The terminal command to run
---@return boolean True if successful
local function spawn_dropdown_terminal(terminal_cmd)
    local pos = calculate_dropdown_position()
    local active_ws = hl.get_active_workspace()
    local current_ws = active_ws and active_ws.id or 1

    local count_before = #hl.get_windows()

    -- Launch the terminal hidden in the special workspace.
    -- Pass the rule string in [...]; the bash -c shell handles the rest.
    hl.dispatch(hl.dsp.exec_cmd(string.format(
        "[float; size %d %d; workspace %s silent] %s",
        pos.width, pos.height, SPECIAL_WORKSPACE, terminal_cmd
    )))
    helpers.sleep(0.1)

    local count_after = #hl.get_windows()
    local new_addr = nil

    if count_after > count_before then
        new_addr = most_recent_window_address()
    end

    if not new_addr or new_addr == "" then
        return false
    end

    helpers.write_file(DROPDOWN_ADDR_FILE, string.format("%s %s", new_addr, pos.monitor_name))

    hl.dispatch(hl.dsp.window.move({
        workspace = current_ws, silent = true, window = "address:" .. new_addr,
    }))
    hl.dispatch(hl.dsp.window.pin({ window = "address:" .. new_addr }))

    animate_slide_down(new_addr, pos.x, pos.y, pos.width, pos.height)

    return true
end

---Toggle the dropdown terminal
-- Creates a floating terminal that slides down from the top
-- Can be hidden to a special scratchpad workspace
-- @function toggle_dropdown
function system.toggle_dropdown()
    local success, err = pcall(function()
        local terminal_cmd = os.getenv("TERMINAL") or "kitty"
        local addr = get_dropdown_address()

        if addr and dropdown_exists(addr) then
            local window_sel = "address:" .. addr
            local active_ws = hl.get_active_workspace()
            local current_ws = active_ws and active_ws.id or 1

            local active_monitor = hl.get_active_monitor()
            local focused_monitor = active_monitor and active_monitor.name or ""
            local dropdown_monitor = get_dropdown_monitor() or ""

            if focused_monitor ~= "" and focused_monitor ~= dropdown_monitor then
                local pos = calculate_dropdown_position()
                move_window_to(addr, pos.x, pos.y)
                resize_window_to(addr, pos.width, pos.height)
                helpers.write_file(DROPDOWN_ADDR_FILE, string.format("%s %s", addr, pos.monitor_name))
            end

            if dropdown_in_special(addr) then
                local pos = calculate_dropdown_position()
                hl.dispatch(hl.dsp.window.move({
                    workspace = current_ws, silent = true, window = window_sel,
                }))
                hl.dispatch(hl.dsp.window.pin({ window = window_sel }))
                resize_window_to(addr, pos.width, pos.height)
                animate_slide_down(addr, pos.x, pos.y, pos.width, pos.height)
                hl.dispatch(hl.dsp.focus({ window = window_sel }))
            else
                local geom = get_window_geometry(addr)

                if geom then
                    animate_slide_up(addr, geom.x, geom.y, geom.width, geom.height)
                    helpers.sleep(0.1)
                end

                hl.dispatch(hl.dsp.window.pin({ window = window_sel })) -- toggle pin off
                hl.dispatch(hl.dsp.window.move({
                    workspace = SPECIAL_WORKSPACE, silent = true, window = window_sel,
                }))
            end
        else
            if spawn_dropdown_terminal(terminal_cmd) then
                local new_addr = get_dropdown_address()
                if new_addr then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. new_addr }))
                end
            else
                notify_error("Failed to spawn dropdown terminal")
            end
        end
    end)

    if not success then
        notify_error("Dropdown terminal failed", tostring(err))
    end
end

-- ============================================
-- BATTERY STATUS
-- ============================================

---Get battery status information from /sys/class/power_supply/
-- Reads capacity and status from all BAT* devices
-- Returns JSON formatted for Waybar integration
-- @return string JSON with text, class, and tooltip
-- @function battery_status
function system.battery_status()
    local success, result = pcall(function()
        local batteries = {}
        local total_capacity = 0
        local battery_count = 0
        local statuses = {}

        -- Check for batteries BAT0 through BAT9
        for i = 0, 9 do
            local bat_path = string.format("/sys/class/power_supply/BAT%d", i)

            -- Use the capacity file's existence as a proxy for "battery present".
            local cap_data = helpers.read_file(bat_path .. "/capacity")
            if cap_data then
                local capacity = tonumber(cap_data:match("%d+")) or 0
                local status_data = helpers.read_file(bat_path .. "/status")
                local status = status_data and status_data:gsub("%s+$", "") or "Unknown"

                table.insert(batteries, {
                    index = i,
                    capacity = capacity,
                    status = status
                })

                total_capacity = total_capacity + capacity
                battery_count = battery_count + 1
                table.insert(statuses, status)
            end
        end

        if battery_count == 0 then
            return '{"text": "N/A", "class": "unknown", "tooltip": "No battery found"}'
        end

        -- Calculate average capacity and determine overall status
        local avg_capacity = math.floor(total_capacity / battery_count)
        local overall_status = statuses[1] or "Unknown"

        -- Determine class based on capacity
        local class
        if avg_capacity > 60 then
            class = "good"
        elseif avg_capacity >= 20 then
            class = "medium"
        else
            class = "low"
        end

        -- Build tooltip
        local tooltip_parts = {}
        for _, bat in ipairs(batteries) do
            table.insert(tooltip_parts, string.format("Battery %d: %d%% (%s)", bat.index, bat.capacity, bat.status))
        end

        local tooltip = table.concat(tooltip_parts, "\n")
        if battery_count == 1 then
            tooltip = string.format("Battery: %d%% (%s)", batteries[1].capacity, batteries[1].status)
        end

        -- Build JSON
        local json = string.format(
            '{"text": "%d%%", "class": "%s", "tooltip": "%s"}',
            avg_capacity,
            class,
            tooltip:gsub("\"", "\\\"")
        )

        return json
    end)

    if success then
        return result
    else
        return '{"text": "ERR", "class": "error", "tooltip": "Failed to read battery status"}'
    end
end

-- ============================================
-- SYSTEM UPTIME
-- ============================================

---Read and format system uptime from /proc/uptime
-- Returns a human-readable string like "3 days, 2 hours, 15 minutes"
-- Removes plural suffixes when value is 1, hides empty fields
-- @return string Formatted uptime string
-- @function uptime
function system.uptime()
    local success, result = pcall(function()
        local data = helpers.read_file("/proc/uptime")

        if not data then
            return "Error: Could not read uptime"
        end

        -- Parse uptime (first number is seconds)
        local uptime_seconds = tonumber(data:match("^(%d+)")) or 0

        if uptime_seconds == 0 then
            return "up 0 seconds"
        end

        -- Calculate days, hours, minutes
        local days = math.floor(uptime_seconds / 86400)
        local hours = math.floor((uptime_seconds % 86400) / 3600)
        local minutes = math.floor((uptime_seconds % 3600) / 60)

        -- Build parts array
        local parts = {}

        if days > 0 then
            local day_str = days == 1 and "day" or "days"
            table.insert(parts, string.format("%d %s", days, day_str))
        end

        if hours > 0 then
            local hour_str = hours == 1 and "hour" or "hours"
            table.insert(parts, string.format("%d %s", hours, hour_str))
        end

        if minutes > 0 then
            local min_str = minutes == 1 and "minute" or "minutes"
            table.insert(parts, string.format("%d %s", minutes, min_str))
        end

        -- Join parts with commas
        local uptime_str = table.concat(parts, ", ")

        if uptime_str == "" then
            return "up < 1 minute"
        end

        return "up " .. uptime_str
    end)

    if success then
        return result
    else
        return "Error: Failed to read uptime"
    end
end

-- ============================================
-- APPLICATION LAUNCHERS
-- ============================================

---Launch the default terminal emulator
---@function terminal
function system.terminal()
    hl.exec_cmd(TERMINAL)
end

---Launch the default file manager
---@function file_manager
function system.file_manager()
    hl.exec_cmd(FILE_MANAGER)
end

---Open btop system monitor in a terminal window
---@function btop
function system.btop()
    hl.exec_cmd(TERMINAL .. " --title btop sh -c 'btop'")
end

---Open nvtop GPU monitor in a terminal window
---@function nvtop
function system.nvtop()
    hl.exec_cmd(TERMINAL .. " --title nvtop sh -c 'nvtop'")
end

---Open nmtui network manager in a terminal window
---@function nmtui
function system.nmtui()
    hl.exec_cmd(TERMINAL .. " nmtui")
end

-- ============================================
-- XDG DESKTOP PORTALS
-- ============================================

---Start XDG Desktop Portals for Hyprland
-- Kills any existing portal processes and starts fresh ones
-- Waits between kills and starts to ensure clean state
-- @function start_portals
function system.start_portals()
    local success, err = pcall(function()
        -- Kill existing portal processes
        hl.exec_cmd("killall xdg-desktop-portal-hyprland 2>/dev/null || true")
        hl.exec_cmd("killall xdg-desktop-portal-wlr 2>/dev/null || true")
        hl.exec_cmd("killall xdg-desktop-portal-gnome 2>/dev/null || true")
        hl.exec_cmd("killall xdg-desktop-portal 2>/dev/null || true")

        helpers.sleep(1)

        -- Start hyprland portal (try both common paths)
        hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland 2>/dev/null &")
        hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null &")

        helpers.sleep(2)

        -- Start generic portal (try both common paths)
        hl.exec_cmd("/usr/lib/xdg-desktop-portal 2>/dev/null &")
        hl.exec_cmd("/usr/libexec/xdg-desktop-portal 2>/dev/null &")
    end)

    if not success then
        notify_error("Failed to start portals", tostring(err))
    end
end

return system
