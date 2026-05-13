-- Session: screen lock, power menu, screenshots, key-hint viewers.

local session = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local icons   = require("utils.icons")
local proc    = require("utils.proc")

local HOME     = os.getenv("HOME")
local ROFI_DIR = HOME .. "/.config/rofi"

local SOUND_DIRS = {
    "/run/current-system/sw/share/sounds/freedesktop/stereo",
    "/usr/share/sounds/freedesktop/stereo",
    HOME .. "/.local/share/sounds/freedesktop/stereo",
}

-- ============================================
-- HELPERS
-- ============================================

local function play_sound(pattern)
    local dirs = table.concat(SOUND_DIRS, " ")
    hl.exec_cmd(string.format(
        [[for d in %s; do f=$(ls "$d"/%s 2>/dev/null | head -1); [ -n "$f" ] && { pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; break; }; done]],
        dirs, pattern
    ))
end

local function play_screenshot_sound() play_sound("screen-capture.*") end
local function play_error_sound()      play_sound("dialog-error.*")    end

local function screenshot_dir()
    local r = helpers.exec("xdg-user-dir PICTURES")
    return helpers.trim(r.stdout) .. "/Screenshots"
end

local function screenshot_filename()
    return string.format("Screenshot_%s_%d.png", os.date("%d-%b_%H-%M-%S"), math.random(1000, 9999))
end

-- Show an interactive notification with Open/Delete actions for a saved screenshot.
local function notify_screenshot(filepath, title)
    local cmd = string.format(
        "notify-send -t 10000 -A action1=Open -A action2=Delete -h string:x-canonical-private-synchronous:shot-notify -i %s %s",
        helpers.shquote(icons.system.screenshot),
        helpers.shquote(title or "Screenshot Saved")
    )
    helpers.exec_async(cmd, function(_, response)
        response = helpers.trim(response)
        if response == "action1" then
            hl.exec_cmd("xdg-open " .. helpers.shquote(filepath) .. " &")
        elseif response == "action2" then
            hl.exec_cmd("rm " .. helpers.shquote(filepath))
        end
    end)
end

local function notify_screenshot_error(title)
    notify.error(title or "Screenshot NOT Saved")
    play_error_sound()
end

-- Core screenshot capture: runs grim + wl-copy, then notifies.
local function capture_fullscreen(filepath)
    local dir = filepath:match("^(.+)/")
    helpers.exec_async(
        string.format("cd %s && grim - | tee %s | wl-copy",
            helpers.shquote(dir), helpers.shquote(filepath:match("[^/]+$"))),
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

local function new_filepath()
    local dir = screenshot_dir()
    helpers.mkdir_p(dir)
    return dir .. "/" .. screenshot_filename()
end

local function countdown_then(seconds, cb)
    if seconds <= 0 then cb(); return end
    notify.send({ text = string.format("Taking shot in: %d secs", seconds),
                  icon = icons.system.timer, timeout = 1000 })
    helpers.delay(1, function() countdown_then(seconds - 1, cb) end)
end

-- ============================================
-- LOCK / POWER MENU
-- ============================================

function session.lock()
    hl.exec_cmd("loginctl lock-session")
    notify.lock()
end

local function get_monitor_info()
    local m = hl.get_active_monitor()
    if not m then return 1080, 1.0 end
    return math.floor(m.height / m.scale), m.scale
end

local function wlogout_margins(height, scale)
    local base
    if     height >= 2160 then base = 600
    elseif height >= 1440 then base = 400
    elseif height >= 1080 then base = 450
    elseif height >= 720  then base = 250
    else                       base = 200
    end
    return math.floor(base / scale), math.floor(base / scale)
end

function session.logout()
    helpers.exec_async("pkill -x wlogout", function(_, _)
        local height, scale = get_monitor_info()
        local t, b         = wlogout_margins(height, scale)
        local bpr          = (height <= 1600) and 3 or 6
        hl.exec_cmd(string.format(
            "wlogout --protocol layer-shell -b %d -T %d -B %d -l %s -C %s &",
            bpr, t, b,
            helpers.shquote(HOME .. "/.config/wlogout/layout"),
            helpers.shquote(HOME .. "/.config/wlogout/style.css")
        ))
    end)
end

-- ============================================
-- SCREENSHOTS
-- ============================================

local function screenshot_now()
    capture_fullscreen(new_filepath())
end

local function screenshot_timer(seconds)
    countdown_then(seconds, function() capture_fullscreen(new_filepath()) end)
end

local function screenshot_window()
    local w = hl.get_active_window()
    if not w then notify_screenshot_error("No active window found"); return end

    local filepath = screenshot_dir() .. "/" ..
        string.format("Screenshot_%s_%s.png", os.date("%d-%b_%H-%M-%S"), w.class or "window")
    helpers.mkdir_p(screenshot_dir())

    local geom = string.format("%d,%d %dx%d", w.at[1], w.at[2], w.size[1], w.size[2])

    helpers.exec_async(
        string.format("grim -g %s %s && wl-copy < %s",
            helpers.shquote(geom), helpers.shquote(filepath), helpers.shquote(filepath)),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(filepath) then
                notify_screenshot_error("Window screenshot failed")
            else
                play_screenshot_sound()
                notify_screenshot(filepath, "Screenshot of " .. (w.class or "window"))
            end
        end
    )
end

local function screenshot_area()
    local filepath = new_filepath()
    local tmpfile  = "/tmp/screenshot_area_" .. tostring(math.random(9999)) .. ".png"

    helpers.exec_async(
        string.format('grim -g "$(slurp)" - > %s', tmpfile),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(tmpfile) then return end
            hl.exec_cmd("wl-copy < " .. tmpfile)
            os.rename(tmpfile, filepath)
            play_screenshot_sound()
            notify_screenshot(filepath, "Screenshot Saved")
        end
    )
end

local function screenshot_swappy()
    local tmpfile = "/tmp/screenshot_swappy_" .. tostring(math.random(9999)) .. ".png"

    helpers.exec_async(
        string.format('grim -g "$(slurp)" - > %s', tmpfile),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(tmpfile) then return end
            hl.exec_cmd("wl-copy < " .. tmpfile)
            play_screenshot_sound()

            local cmd = string.format(
                "notify-send -t 10000 -A action1=Open -A action2=Delete -h string:x-canonical-private-synchronous:shot-notify -i %s %s",
                helpers.shquote(icons.system.screenshot), helpers.shquote("Captured by Swappy")
            )
            helpers.exec_async(cmd, function(_, response)
                response = helpers.trim(response)
                if response == "action1" then
                    hl.exec_cmd("swappy -f - < " .. tmpfile)
                elseif response == "action2" then
                    os.remove(tmpfile)
                end
            end)
        end
    )
end

local SCREENSHOT_DISPATCH = {
    now     = screenshot_now,
    area    = screenshot_area,
    window  = screenshot_window,
    swappy  = screenshot_swappy,
    ["5"]   = function() screenshot_timer(5)  end,
    ["10"]  = function() screenshot_timer(10) end,
}

function session.screenshot(mode)
    helpers.safe_call("Screenshot failed", function()
        local fn = SCREENSHOT_DISPATCH[mode]
        if fn then fn() else notify.error("Unknown screenshot mode: " .. tostring(mode)) end
    end)
end

-- ============================================
-- KEY HINTS (yad) AND SEARCHABLE BINDS (rofi)
-- ============================================

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

function session.show_hints()
    helpers.safe_call("Key hints failed", function()
        -- Toggle off if already open.
        if helpers.trim(helpers.exec("pgrep -x yad").stdout) ~= "" then
            hl.exec_cmd("pkill -x yad"); return
        end
        proc.kill("rofi")

        helpers.get_binds(function(binds)
            if #binds == 0 then notify.error("No keybinds found"); return end

            local args = {}
            for _, b in ipairs(binds) do
                local label = b.description ~= "" and b.description or b.dispatcher
                if label then
                    table.insert(args, shell_quote(b.keys))
                    table.insert(args, shell_quote(label))
                end
            end

            if #args == 0 then notify.error("No displayable keybinds found"); return end

            hl.exec_cmd(
                "GDK_BACKEND=wayland yad --center --width=1000 --height=700 "
                .. "--title='Keybind Cheat Sheet' --no-buttons --list "
                .. "--column=Key: --column=Description: "
                .. table.concat(args, " ")
            )
        end)
    end)
end

function session.show_binds()
    helpers.safe_call("Key binds failed", function()
        proc.kill("yad"); proc.kill("rofi")

        helpers.get_binds(function(binds)
            if #binds == 0 then notify.error("No keybinds found"); return end

            local lines = {}
            local msg   = "Clicking or pressing ENTER has no function"

            for _, b in ipairs(binds) do
                local label = b.description ~= "" and b.description
                    or (b.dispatcher ~= "" and
                        (b.arg ~= "" and (b.dispatcher .. ": " .. b.arg) or b.dispatcher))
                if label then
                    table.insert(lines, string.format("%-36s  %s", b.keys, label))
                end
            end

            if #lines == 0 then notify.error("No displayable keybinds found"); return end

            local input    = table.concat(lines, "\n")
            local rofi_cmd = string.format(
                "echo %s | rofi -dmenu -i -config %s -mesg %s &",
                shell_quote(input),
                shell_quote(ROFI_DIR .. "/config-keybinds.rasi"),
                shell_quote(msg)
            )
            hl.exec_cmd(rofi_cmd)
        end)
    end)
end

return session
