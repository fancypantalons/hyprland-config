---
-- Session and Screenshot Functions
-- Provides screen lock, power menu, screenshots, and key hints
--
-- @module user-functions.session
-- @author Brett
-- @license MIT

local session = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local ICON_DIR = os.getenv("HOME") .. "/.config/swaync/icons"
local IMAGE_DIR = os.getenv("HOME") .. "/.config/swaync/images"
local ROFI_DIR  = os.getenv("HOME") .. "/.config/rofi"

local SOUND_DIRS = {
    "/run/current-system/sw/share/sounds/freedesktop/stereo",
    "/usr/share/sounds/freedesktop/stereo",
    os.getenv("HOME") .. "/.local/share/sounds/freedesktop/stereo",
}

local ICON_PICTURE = ICON_DIR .. "/picture.png"
local ICON_NOTE = IMAGE_DIR .. "/note.png"
local ICON_TIMER = ICON_DIR .. "/timer.png"

-- Screenshot modes
local SCREENSHOT_MODES = {
    NOW = "now",
    AREA = "area",
    WINDOW = "window",
    TIMER_5 = "5",
    TIMER_10 = "10",
    SWAPPY = "swappy"
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Get the screenshot directory path
-- Uses xdg-user-dir to find the Pictures directory
-- @return string The full path to the Screenshots directory
local function get_screenshot_dir()
    local result = helpers.exec("xdg-user-dir PICTURES")
    local base_dir = result.stdout:gsub("%s+$", "")

    return base_dir .. "/Screenshots"
end

---Generate a filename for screenshots
-- Format: Screenshot_${time}_${RANDOM}.png
-- @return string The generated filename
local function generate_filename()
    local time_str = os.date("%d-%b_%H-%M-%S")
    local random_val = math.random(1000, 9999)

    return string.format("Screenshot_%s_%d.png", time_str, random_val)
end

---Ensure the screenshots directory exists
-- Creates the directory if it doesn't exist
local function ensure_screenshot_dir()
    local dir = get_screenshot_dir()
    helpers.mkdir_p(dir)

    return dir
end

---Get active window geometry for screenshots
-- @return string|nil The geometry string "x,y WxH" or nil on error
local function get_active_window_geometry()
    local w = hl.get_active_window()
    if not w then
        return nil
    end
    return string.format("%d,%d %dx%d", w.at[1], w.at[2], w.size[1], w.size[2])
end

---Get active window class name
-- @return string|nil The window class name or nil on error
local function get_active_window_class()
    local w = hl.get_active_window()
    return w and w.class or nil
end

---Generate filename for active window screenshot
-- Format: Screenshot_${time}_${class}.png
-- @param class string The window class name
-- @return string The generated filename
local function generate_active_window_filename(class)
    local time_str = os.date("%d-%b_%H-%M-%S")

    return string.format("Screenshot_%s_%s.png", time_str, class)
end

---Find and play a freedesktop sound by glob pattern.
-- Searches SOUND_DIRS in order and plays the first match via pw-play or paplay.
-- Fully async — no blocking exec needed since we don't use the return value.
-- @param pattern string Shell glob for the filename, e.g. "screen-capture.*"
local function play_sound(pattern)
    local dirs = table.concat(SOUND_DIRS, " ")
    hl.exec_cmd(string.format(
        [[for d in %s; do f=$(ls "$d"/%s 2>/dev/null | head -1); [ -n "$f" ] && { pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; break; }; done]],
        dirs, pattern
    ))
end

local function play_screenshot_sound() play_sound("screen-capture.*") end
local function play_error_sound()      play_sound("dialog-error.*")    end

---Async countdown: show notifications and invoke cb when done.
-- @param seconds number
-- @param cb function Called when countdown reaches zero
local function countdown_then(seconds, cb)
    if seconds <= 0 then
        cb()
        return
    end

    notify.send({
        text = string.format("Taking shot in: %d secs", seconds),
        icon = ICON_TIMER,
        timeout = 1000
    })

    helpers.delay(1, function()
        countdown_then(seconds - 1, cb)
    end)
end

---Show screenshot notification with actions (async, non-blocking)
-- Displays a notification with Open and Delete actions.
-- @param filepath string The path to the screenshot file
-- @param title string The notification title
local function notify_screenshot(filepath, title)
    local notify_cmd = string.format(
        'notify-send -t 10000 -A action1=Open -A action2=Delete -h string:x-canonical-private-synchronous:shot-notify -i %s "%s"',
        ICON_PICTURE,
        title or "Screenshot Saved"
    )

    helpers.exec_async(notify_cmd, function(_, response)
        response = response:gsub("%s+$", "")

        if response == "action1" then
            hl.exec_cmd("xdg-open '" .. filepath .. "' &")
        elseif response == "action2" then
            hl.exec_cmd("rm '" .. filepath .. "'")
        end
    end)
end

---Show error notification for failed screenshot
-- @param title string The error title
local function notify_screenshot_error(title)
    local notify = require("utils.notify")
    notify.error(title or "Screenshot NOT Saved")
    play_error_sound()
end

-- ============================================
-- SCREEN LOCK
-- ============================================

---Lock the screen using loginctl
-- Uses the session manager to lock the session
-- @function lock
function session.lock()
    hl.exec_cmd("loginctl lock-session")
    notify.lock()
end

-- ============================================
-- LOGOUT / POWER MENU
-- ============================================

---Get the focused monitor's logical height and scale factor.
-- "Logical height" = pixel height divided by scale, truncated like the old
-- shell pipeline did (`height / scale | awk '{print $1}'` discarded fractional).
-- @return number height
-- @return number scale
local function get_monitor_info()
    local m = hl.get_active_monitor()
    if not m then
        return 1080, 1.0
    end
    return math.floor(m.height / m.scale), m.scale
end

---Calculate wlogout margins based on screen resolution
-- @param height number The monitor height
-- @param scale number The monitor scale factor
-- @return number t_val The top margin
-- @return number b_val The bottom margin
local function calculate_margins(height, scale)
    -- Base margins for different resolutions
    local margins = {
        [2160] = { t = 600, b = 600 },
        [1600] = { t = 400, b = 400 },
        [1440] = { t = 400, b = 400 },
        [1080] = { t = 450, b = 450 },
        [720] = { t = 250, b = 250 }
    }

    local base_t, base_b

    if height >= 2160 then
        base_t, base_b = 600, 600
    elseif height >= 1600 then
        base_t, base_b = 400, 400
    elseif height >= 1440 then
        base_t, base_b = 400, 400
    elseif height >= 1080 then
        base_t, base_b = 450, 450
    elseif height >= 720 then
        base_t, base_b = 250, 250
    else
        base_t, base_b = 200, 200
    end

    -- Adjust for scale: shrink margins on HiDPI
    local t_val = math.floor(base_t / scale)
    local b_val = math.floor(base_b / scale)

    return t_val, b_val
end

---Show the power menu (wlogout)
-- Detects monitor resolution, calculates margins, and launches wlogout
-- Kills existing wlogout instance first
-- @function logout
function session.logout()
    helpers.exec_async(
        "pkill -x wlogout", 
        function(_, _)
            -- Get monitor info
            local height, scale = get_monitor_info()
  
            -- Calculate margins
            local t_val, b_val = calculate_margins(height, scale)
  
            -- Determine buttons per row: 3 for 2k and below (2 rows), 6 for higher resolutions (1 row)
            local buttons_per_row = 6
  
            if (height <= 1600) then
                buttons_per_row = 3
            end
  
            -- Launch wlogout with explicit config paths
            local home = os.getenv("HOME")
            local wlogout_cmd = string.format(
                "wlogout --protocol layer-shell -b %d -T %d -B %d -l '%s/.config/wlogout/layout' -C '%s/.config/wlogout/style.css' &",
                buttons_per_row,
                t_val,
                b_val,
                home,
                home
            )
  
            hl.exec_cmd(wlogout_cmd)
        end
    )
end

-- ============================================
-- SCREENSHOT FUNCTIONS
-- ============================================

---Take an immediate screenshot
-- Captures the entire screen and copies to clipboard
-- Saves to the Screenshots directory
local function screenshot_now()
    local dir = ensure_screenshot_dir()
    local filename = generate_filename()
    local filepath = dir .. "/" .. filename

    helpers.exec_async(
        string.format("cd %s && grim - | tee %s | wl-copy", dir, filename),
        function(exit_code, _)
            if exit_code == 0 and helpers.path_exists(filepath) then
                play_screenshot_sound()
                notify_screenshot(filepath, "Screenshot Saved")
            else
                notify_screenshot_error("Screenshot NOT Saved")
            end
        end
    )
end

---Take a screenshot with a timer
-- Shows countdown, then captures the entire screen
-- @param seconds number The number of seconds to wait
local function screenshot_timer(seconds)
    countdown_then(seconds, function()
        local dir = ensure_screenshot_dir()
        local filename = generate_filename()
        local filepath = dir .. "/" .. filename

        helpers.exec_async(
            string.format("cd %s && grim - | tee %s | wl-copy", dir, filename),
            function(exit_code, _)
                if exit_code == 0 and helpers.path_exists(filepath) then
                    play_screenshot_sound()
                    notify_screenshot(filepath, "Screenshot Saved")
                else
                    notify_screenshot_error("Screenshot NOT Saved")
                end
            end
        )
    end)
end

---Take a screenshot of the active window
-- Captures only the currently focused window
local function screenshot_window()
    local dir = ensure_screenshot_dir()
    local class = get_active_window_class()

    if (not class) then
        notify_screenshot_error("No active window found")

        return
    end

    local filename = generate_active_window_filename(class)
    local filepath = dir .. "/" .. filename

    local geometry = get_active_window_geometry()

    if (not geometry) then
        notify_screenshot_error("Failed to get window geometry")

        return
    end

    helpers.exec_async(
        string.format("grim -g '%s' %s && wl-copy < %s", geometry, filepath, filepath),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(filepath) then
                hl.exec_cmd(string.format(
                    'notify-send -u low -i %s " Screenshot of:" " %s NOT Saved."',
                    ICON_NOTE,
                    class
                ))
                play_error_sound()

                return
            end

            play_screenshot_sound()
            notify_screenshot(filepath, " Screenshot of: " .. class .. " Saved.")
        end
    )
end

---Take a screenshot of a selected area
-- Uses slurp for area selection
local function screenshot_area()
    local dir = ensure_screenshot_dir()
    local filename = generate_filename()
    local filepath = dir .. "/" .. filename

    local tmpfile = "/tmp/screenshot_area_" .. tostring(math.random(1000, 9999)) .. ".png"

    helpers.exec_async(
        string.format('grim -g "$(slurp)" - > %s', tmpfile),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(tmpfile) then
                return
            end

            hl.exec_cmd("wl-copy < " .. tmpfile)
            os.rename(tmpfile, filepath)

            play_screenshot_sound()
            notify_screenshot(filepath, "Screenshot Saved")
        end
    )
end

---Take a screenshot and open in swappy
-- Uses slurp for area selection, then opens in swappy editor
local function screenshot_swappy()
    local tmpfile = "/tmp/screenshot_swappy_" .. tostring(math.random(1000, 9999)) .. ".png"

    helpers.exec_async(
        string.format('grim -g "$(slurp)" - > %s', tmpfile),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(tmpfile) then
                return
            end

            hl.exec_cmd("wl-copy < " .. tmpfile)
            play_screenshot_sound()

            local notify_cmd = string.format(
                'notify-send -t 10000 -A action1=Open -A action2=Delete ' ..
                '-h string:x-canonical-private-synchronous:shot-notify ' ..
                '-i %s " Screenshot:" " Captured by Swappy"',
                ICON_PICTURE
            )

            helpers.exec_async(notify_cmd, function(_, response)
                response = response:gsub("%s+$", "")

                if response == "action1" then
                    hl.exec_cmd("swappy -f - < " .. tmpfile)
                elseif response == "action2" then
                    os.remove(tmpfile)
                end
            end)
        end
    )
end

---Take a screenshot with various modes
-- Supports: "now" (immediate), "area" (slurp selection), "window" (active window),
-- "5" (5s timer), "10" (10s timer), "swappy" (to swappy editor)
-- @function screenshot
-- @param mode string The screenshot mode
function session.screenshot(mode)
    helpers.safe_call("Screenshot failed", function()
        if mode == SCREENSHOT_MODES.NOW then
            screenshot_now()
        elseif mode == SCREENSHOT_MODES.AREA then
            screenshot_area()
        elseif mode == SCREENSHOT_MODES.WINDOW then
            screenshot_window()
        elseif mode == SCREENSHOT_MODES.TIMER_5 then
            screenshot_timer(5)
        elseif mode == SCREENSHOT_MODES.TIMER_10 then
            screenshot_timer(10)
        elseif mode == SCREENSHOT_MODES.SWAPPY then
            screenshot_swappy()
        else
            local notify = require("utils.notify")
            notify.error("Unknown screenshot mode: " .. tostring(mode))
        end
    end)
end

-- ============================================
-- KEY HINTS
-- ============================================

---Shell-quote a string for safe use as a command-line argument.
-- Wraps in single quotes, escaping any embedded single quotes.
-- @param s string
-- @return string
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

---Show key hints with yad
-- Kills existing rofi/yad first, then launches yad with live bind list.
-- Reads the cached binds file (populated by autostart/reload hooks) to avoid
-- calling hyprctl from inside a keybind handler (which would deadlock).
-- @function show_hints
function session.show_hints()
    helpers.safe_call("Key hints failed", function()
        -- Toggle: kill yad if it's already open, otherwise launch it
        local check = helpers.exec("pgrep -x yad")

        if check.stdout ~= "" then
            hl.exec_cmd("pkill -x yad")
            return
        end

        hl.exec_cmd("pkill -x rofi 2>/dev/null || true")

        helpers.get_binds(function(binds)
            if #binds == 0 then
                notify.error("No keybinds found", "Bind cache may not be populated yet")
                return
            end

            -- Build yad args from live bind list
            local yad_args = {}
            for _, bind in ipairs(binds) do
                local label
                local detail

                if bind.description ~= "" then
                    label = bind.description
                elseif bind.dispatcher ~= "" then
                    label = bind.dispatcher
                end

                if bind.arg ~= "" then
                    detail = bind.arg
                end

                if label then
                    table.insert(yad_args, shell_quote(bind.keys))
                    table.insert(yad_args, shell_quote(label))
                end
            end

            if #yad_args == 0 then
                notify.error("No displayable keybinds found")
                return
            end

            local yad_cmd = "GDK_BACKEND=wayland yad --center --width=1000 --height=700 --title='Keybind Cheat Sheet' --no-buttons --list --column=Key: --column=Description: "
                .. table.concat(yad_args, " ")

            hl.exec_cmd(yad_cmd)
        end)
    end)
end

-- ============================================
-- KEY BINDS (SEARCHABLE)
-- ============================================

---Show searchable keybinds with rofi
-- Retrieves the live bind list from Hyprland via helpers.get_binds(), formats
-- each entry as "keys   label" where label is the bind's description when set,
-- or "dispatcher: arg" as a fallback.  Binds with neither are omitted.
-- @function show_binds
function session.show_binds()
    helpers.safe_call("Key binds failed", function()
        hl.exec_cmd("pkill -x yad 2>/dev/null || true")
        hl.exec_cmd("pkill -x rofi 2>/dev/null || true")

        helpers.get_binds(function(binds)
            if #binds == 0 then
                local notify = require("utils.notify")
                notify.error("No keybinds found", "Bind cache may not be populated yet")
                return
            end

            local lines = {}
            local msg = "☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function"

            for _, bind in ipairs(binds) do
                local label

                if bind.description ~= "" then
                    label = bind.description
                elseif bind.dispatcher ~= "" then
                    label = bind.arg ~= "" and (bind.dispatcher .. ": " .. bind.arg)
                                           or bind.dispatcher
                end

                if label then
                    table.insert(lines, string.format("%-36s  %s", bind.keys, label))
                end
            end

            if #lines == 0 then
                local notify = require("utils.notify")
                notify.error("No displayable keybinds found")
                return
            end

            local menu_input = table.concat(lines, "\n")
            local rofi_theme = ROFI_DIR .. "/config-keybinds.rasi"
            local rofi_cmd = string.format(
                "echo '%s' | rofi -dmenu -i -config %s -mesg '%s' &",
                menu_input:gsub("'", "'\"'\"'"),
                rofi_theme,
                msg
            )

            hl.exec_cmd(rofi_cmd)
        end)
    end)
end

return session
