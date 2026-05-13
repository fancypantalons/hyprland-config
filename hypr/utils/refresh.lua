-- UI refresh utilities: restart waybar, ags, swaync, and optional extras.

local refresh = {}
local helpers = require("utils.helpers")
local proc    = require("utils.proc")

local HOME        = os.getenv("HOME")
local SCRIPTS_DIR = HOME .. "/.config/hypr/scripts"

-- Chain {async=, cmd=, fn=, delay=} steps, calling cb when all complete.
local function seq(steps, cb)
    local function run(i)
        if i > #steps then if cb then pcall(cb) end; return end
        local s = steps[i]
        if s.delay then
            helpers.delay(s.delay, function() pcall(run, i + 1) end)
        elseif s.async then
            helpers.exec_async(s.async, function() pcall(run, i + 1) end)
        elseif s.fn then
            s.fn(); run(i + 1)
        elseif s.cmd then
            hl.exec_cmd(s.cmd); run(i + 1)
        end
    end
    pcall(run, 1)
end

local function rainbow_borders()
    local path = SCRIPTS_DIR .. "/RainbowBorders.sh"
    if helpers.file_exists(path) then hl.exec_cmd(path .. " &") end
end

-- Full UI restart: ags + waybar + swaync + optional RainbowBorders.
function refresh.refresh_ui(cb)
    for _, p in ipairs({"waybar", "rofi", "swaync", "ags"}) do proc.kill(p) end
    proc.signal("waybar", "SIGUSR2")

    seq({
        { async = "ags -q 2>/dev/null || true; sleep 0.1" },
        { cmd   = "ags &" },
        { fn    = function()
            for _, p in ipairs({"waybar", "rofi", "swaync", "ags", "swaybg"}) do
                if proc.running(p) then proc.signal(p, "SIGUSR1") end
            end
          end },
        { delay = 1   },
        { cmd   = "waybar &" },
        { delay = 0.5 },
        { cmd   = "swaync > /dev/null 2>&1 &" },
        { delay = 0.2 },
        { cmd   = "swaync-client --reload-config" },
        { delay = 1   },
        { fn    = rainbow_borders },
    }, cb)
end

-- Refresh without restarting waybar (used after wallpaper/wallust changes).
function refresh.refresh_ui_no_waybar(cb)
    proc.kill("rofi")

    seq({
        { async = "ags -q 2>/dev/null || true; sleep 0.1" },
        { cmd   = "ags &" },
        { fn    = function() require("user-functions.wallpaper").apply_wallust() end },
        { delay = 0.2 },
        { cmd   = "swaync-client --reload-config" },
        { delay = 1   },
        { fn    = rainbow_borders },
    }, cb)
end

return refresh
