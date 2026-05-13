-- System control: airplane mode, touchpad, clipboard, idle inhibitor, polkit,
-- dropdown terminal, battery status, uptime, application launchers, XDG portals.

local system  = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local proc    = require("utils.proc")
local state   = require("utils.state")
local devices = require("devices")

local HOME     = os.getenv("HOME")
local TERMINAL = "kitty"
local FILE_MGR = "thunar"

local CLIPBOARD_THEME = HOME .. "/.config/rofi/config-clipboard.rasi"

local DROPDOWN_CONFIG = { width_pct = 50, height_pct = 50, y_pct = 5 }
local SPECIAL_WS      = "special:scratchpad"

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
    "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1",
}

-- ============================================
-- AIRPLANE MODE
-- ============================================

function system.airplane_mode()
    helpers.safe_call("Airplane mode toggle failed", function()
        local on = helpers.exec("/sbin/rfkill list wifi | grep 'Soft blocked: no'")
        local blocking = on.success and on.stdout ~= ""

        if blocking then
            helpers.exec("/sbin/rfkill block wifi")
            notify.info("Airplane mode: ON")
        else
            helpers.exec("/sbin/rfkill unblock wifi")
            notify.info("Airplane mode: OFF")
        end
    end)
end

-- ============================================
-- TOUCHPAD
-- ============================================

local function set_touchpad(enabled)
    state.set("touchpad", tostring(enabled))
    hl.device({ name = devices.TOUCHPAD_DEVICE, enabled = enabled })
    notify.info("Touchpad: " .. (enabled and "Enabled" or "Disabled"))
end

function system.touchpad_toggle()
    helpers.safe_call("Touchpad toggle failed", function()
        set_touchpad(state.get("touchpad", "true") ~= "true")
    end)
end

-- ============================================
-- CLIPBOARD MANAGER
-- ============================================

function system.clipboard_manager()
    proc.kill("rofi")

    helpers.exec_async("cliphist list", function(ec, stdout)
        pcall(function()
            if ec ~= 0 or stdout == "" then
                notify.error("Failed to get clipboard history", "Is cliphist installed?")
                return
            end

            local input = helpers.trim(stdout)
            local rofi_cmd = string.format(
                "echo %s | rofi -i -dmenu -kb-custom-1 'Control-Delete' -kb-custom-2 'Alt-Delete' -config %s -mesg %s",
                helpers.shquote(input:gsub("'", "'\"'\"'")),
                helpers.shquote(CLIPBOARD_THEME),
                helpers.shquote("CTRL+DEL = Delete entry | ALT+DEL = Wipe all")
            )

            helpers.exec_async(rofi_cmd, function(rofi_ec, sel)
                pcall(function()
                    sel = helpers.trim(sel)
                    if rofi_ec == 1 or sel == "" then return end

                    local q = helpers.shquote(sel)
                    if rofi_ec == 0 then
                        hl.exec_cmd(string.format("echo %s | cliphist decode | wl-copy", q))
                    elseif rofi_ec == 10 then
                        hl.exec_cmd(string.format("echo %s | cliphist delete", q))
                        notify.info("Clipboard: entry deleted")
                    elseif rofi_ec == 11 then
                        hl.exec_cmd("cliphist wipe")
                        notify.info("Clipboard: history wiped")
                    end
                end)
            end)
        end)
    end)
end

-- ============================================
-- IDLE INHIBITOR
-- ============================================

function system.idle_inhibit_toggle()
    helpers.safe_call("Idle inhibitor toggle failed", function()
        if proc.running("hypridle") then
            helpers.exec("pkill -x hypridle")
            notify.info("Screen auto-lock: Disabled")
        else
            hl.exec_cmd("hypridle &")
            notify.info("Screen auto-lock: Enabled")
        end
    end)
end

function system.idle_inhibit_status()
    return helpers.safe_call("Idle inhibitor status failed", function()
        if proc.running("hypridle") then
            return '{"text":"RUNNING","class":"active","tooltip":"Screen auto-lock: ON\nLeft Click: Disable\nRight Click: Lock now"}'
        else
            return '{"text":"NOT RUNNING","class":"notactive","tooltip":"Screen auto-lock: OFF\nLeft Click: Enable\nRight Click: Lock now"}'
        end
    end, '{"text":"ERROR","class":"error","tooltip":"Failed to check status"}')
end

-- ============================================
-- POLKIT AGENT
-- ============================================

function system.start_polkit()
    helpers.safe_call("Polkit startup failed", function()
        for _, path in ipairs(POLKIT_AGENTS) do
            if helpers.file_exists(path) then
                hl.exec_cmd(path)
                return
            end
        end
        notify.error("No polkit agent found", "Please install a polkit agent")
    end)
end

-- ============================================
-- DROPDOWN TERMINAL
-- ============================================

local function get_monitor_info()
    local m = hl.get_active_monitor()
    if not m then return { x=0, y=0, width=1920, height=1080, scale=1.0, name="DP-1" } end
    return { x=m.x or 0, y=m.y or 0, width=m.width or 1920,
             height=m.height or 1080, scale=m.scale or 1.0, name=m.name or "DP-1" }
end

local function calc_dropdown_pos()
    local m  = get_monitor_info()
    local lw = math.floor(m.width  / m.scale)
    local lh = math.floor(m.height / m.scale)
    local w  = math.floor(lw * DROPDOWN_CONFIG.width_pct  / 100)
    local h  = math.floor(lh * DROPDOWN_CONFIG.height_pct / 100)
    local yo = math.floor(lh * DROPDOWN_CONFIG.y_pct      / 100)
    local xo = math.floor((lw - w) / 2)
    return { x = m.x + xo, y = m.y + yo, width = w, height = h, monitor = m.name }
end

local function dropdown_addr()   return state.get("dropdown_addr", nil)    end
local function dropdown_monitor() return state.get("dropdown_monitor", nil) end

local function dropdown_exists(addr)
    return hl.get_window("address:" .. addr) ~= nil
end

local function in_special(addr)
    local w = hl.get_window("address:" .. addr)
    return w and w.workspace and w.workspace.name == SPECIAL_WS
end

local function most_recent_addr()
    local wins = hl.get_windows()
    table.sort(wins, function(a, b) return (a.focus_history_id or 0) < (b.focus_history_id or 0) end)
    local last = wins[#wins]
    return last and last.address or nil
end

local function poll_for_new_window(count_before, attempts, cb)
    if attempts <= 0 then cb(nil); return end
    if #hl.get_windows() > count_before then
        cb(most_recent_addr())
    else
        helpers.delay(0.05, function() poll_for_new_window(count_before, attempts - 1, cb) end)
    end
end

local function spawn_dropdown(term_cmd, cb)
    local pos    = calc_dropdown_pos()
    local cur_ws = (hl.get_active_workspace() or {}).id or 1
    local before = #hl.get_windows()

    hl.exec_cmd(string.format("[float; size %d %d; workspace %s silent] %s",
        pos.width, pos.height, SPECIAL_WS, term_cmd))

    poll_for_new_window(before, 20, function(addr)
        pcall(function()
            if not addr then cb(false); return end

            state.set("dropdown_addr",    addr)
            state.set("dropdown_monitor", pos.monitor)

            hl.dispatch(hl.dsp.window.move({ workspace = cur_ws, silent = true, window = "address:" .. addr }))
            hl.dispatch(hl.dsp.window.pin({ window = "address:" .. addr }))
            hl.dispatch(hl.dsp.window.move({ x = pos.x, y = pos.y, relative = false, window = "address:" .. addr }))
            cb(true)
        end)
    end)
end

function system.toggle_dropdown()
    helpers.safe_call("Dropdown terminal failed", function()
        local term = os.getenv("TERMINAL") or "kitty"
        local addr = dropdown_addr()

        if addr and dropdown_exists(addr) then
            local win_sel  = "address:" .. addr
            local cur_ws   = (hl.get_active_workspace() or {}).id or 1
            local cur_mon  = (hl.get_active_monitor() or {}).name or ""
            local prev_mon = dropdown_monitor() or ""

            if cur_mon ~= "" and cur_mon ~= prev_mon then
                local pos = calc_dropdown_pos()
                hl.dispatch(hl.dsp.window.move({ x = pos.x, y = pos.y, relative = false, window = win_sel }))
                hl.dispatch(hl.dsp.window.resize({ x = pos.width, y = pos.height, relative = false, window = win_sel }))
                state.set("dropdown_monitor", pos.monitor)
            end

            if in_special(addr) then
                local pos = calc_dropdown_pos()
                hl.dispatch(hl.dsp.window.move({ workspace = cur_ws, silent = true, window = win_sel }))
                hl.dispatch(hl.dsp.window.pin({ window = win_sel }))
                hl.dispatch(hl.dsp.window.resize({ x = pos.width, y = pos.height, relative = false, window = win_sel }))
                hl.dispatch(hl.dsp.window.move({ x = pos.x, y = pos.y, relative = false, window = win_sel }))
                hl.dispatch(hl.dsp.focus({ window = win_sel }))
            else
                hl.dispatch(hl.dsp.window.pin({ window = win_sel }))
                hl.dispatch(hl.dsp.window.move({ workspace = SPECIAL_WS, silent = true, window = win_sel }))
            end
        else
            spawn_dropdown(term, function(ok)
                pcall(function()
                    if not ok then notify.error("Failed to spawn dropdown terminal"); return end
                    local new_addr = dropdown_addr()
                    if new_addr then hl.dispatch(hl.dsp.focus({ window = "address:" .. new_addr })) end
                end)
            end)
        end
    end)
end

-- ============================================
-- BATTERY STATUS
-- ============================================

function system.battery_status()
    return helpers.safe_call("Battery status failed", function()
        local bats, total, count, statuses = {}, 0, 0, {}
        for i = 0, 9 do
            local base = string.format("/sys/class/power_supply/BAT%d", i)
            local cap  = helpers.read_file(base .. "/capacity")
            if cap then
                local c = tonumber(cap:match("%d+")) or 0
                local s = helpers.trim(helpers.read_file(base .. "/status") or "Unknown")
                table.insert(bats, { index = i, capacity = c, status = s })
                total = total + c; count = count + 1
                table.insert(statuses, s)
            end
        end

        if count == 0 then
            return '{"text":"N/A","class":"unknown","tooltip":"No battery found"}'
        end

        local avg   = math.floor(total / count)
        local class = avg > 60 and "good" or avg >= 20 and "medium" or "low"

        local tooltip
        if count == 1 then
            tooltip = string.format("Battery: %d%% (%s)", bats[1].capacity, bats[1].status)
        else
            local parts = {}
            for _, b in ipairs(bats) do
                table.insert(parts, string.format("Battery %d: %d%% (%s)", b.index, b.capacity, b.status))
            end
            tooltip = table.concat(parts, "\n")
        end

        return string.format('{"text":"%d%%","class":"%s","tooltip":"%s"}',
            avg, class, tooltip:gsub('"', '\\"'))
    end, '{"text":"ERR","class":"error","tooltip":"Failed to read battery"}')
end

-- ============================================
-- UPTIME
-- ============================================

function system.uptime()
    return helpers.safe_call("Uptime check failed", function()
        local data = helpers.read_file("/proc/uptime")
        if not data then return "Error: could not read uptime" end

        local secs  = tonumber(data:match("^(%d+)")) or 0
        local days  = math.floor(secs / 86400)
        local hours = math.floor((secs % 86400) / 3600)
        local mins  = math.floor((secs % 3600) / 60)

        local parts = {}
        if days  > 0 then table.insert(parts, days  .. (days  == 1 and " day"    or " days"))    end
        if hours > 0 then table.insert(parts, hours .. (hours == 1 and " hour"   or " hours"))   end
        if mins  > 0 then table.insert(parts, mins  .. (mins  == 1 and " minute" or " minutes")) end

        return "up " .. (table.concat(parts, ", ") ~= "" and table.concat(parts, ", ") or "< 1 minute")
    end, "Error: failed to read uptime")
end

-- ============================================
-- APPLICATION LAUNCHERS
-- ============================================

function system.terminal()    hl.exec_cmd(TERMINAL) end
function system.file_manager() hl.exec_cmd(FILE_MGR) end
function system.btop()  hl.exec_cmd(TERMINAL .. " --title btop sh -c 'btop'") end
function system.nvtop() hl.exec_cmd(TERMINAL .. " --title nvtop sh -c 'nvtop'") end
function system.nmtui() hl.exec_cmd(TERMINAL .. " nmtui") end

-- ============================================
-- XDG DESKTOP PORTALS
-- ============================================

function system.start_portals()
    helpers.exec_async(
        "killall xdg-desktop-portal-hyprland xdg-desktop-portal-wlr "
        .. "xdg-desktop-portal-gnome xdg-desktop-portal 2>/dev/null; sleep 1",
        function(_, _)
            pcall(function()
                hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland 2>/dev/null &")
                hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null &")
                helpers.delay(2, function()
                    hl.exec_cmd("/usr/lib/xdg-desktop-portal 2>/dev/null &")
                    hl.exec_cmd("/usr/libexec/xdg-desktop-portal 2>/dev/null &")
                end)
            end)
        end
    )
end

return system
