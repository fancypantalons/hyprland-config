---
-- Window Management Functions
-- Provides window control, game mode, and layout toggling
--
-- @module user-functions.window
-- @author Brett
-- @license MIT

local window = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- Load refresh module for internal refresh functions
local refresh = require("utils.refresh")

-- ============================================
-- CONFIGURATION
-- ============================================

local IMAGE_DIR = os.getenv("HOME") .. "/.config/swaync/images"
local SCRIPT_DIR = os.getenv("HOME") .. "/.config/hypr/scripts"
local WALLPAPER_PATH = os.getenv("HOME") .. "/.config/rofi/.current_wallpaper"

local ICON = IMAGE_DIR .. "/ja.png"

-- Holds the runtime "force opacity 1" rule installed by enable_game_mode so
-- disable_game_mode can remove it without reloading the whole config.
local game_mode_opacity_rule = nil

-- Snapshot of pre-game-mode config values, so disable_game_mode can restore
-- exactly what was active rather than trying to guess defaults.
local game_mode_saved = nil

-- ============================================
-- ACTIVE WINDOW FUNCTIONS
-- ============================================

---Kill the active window's process
-- Reads the PID from hl.get_active_window() and sends SIGTERM via `kill`.
-- @function kill_active
function window.kill_active()
    local success, err = pcall(function()
        local active = hl.get_active_window()

        if not active or not active.pid or active.pid == 0 then
            notify.error("No active window found")
            return
        end

        local kill_result = helpers.exec("kill " .. tostring(active.pid))

        if not kill_result.success then
            notify.error("Failed to kill process", kill_result.stderr)
        end
    end)

    if not success then
        notify.error("Kill active process failed", tostring(err))
    end
end

-- ============================================
-- GAME MODE
-- ============================================

---Check if animations are currently enabled
-- @return boolean True if animations are enabled, false otherwise
local function is_animations_enabled()
    local success, enabled = pcall(function()
        return hl.config.animations.enabled
    end)

    if not success then
        return true
    end

    return enabled
end

---Enable game mode by disabling animations and effects
-- Disables: animations, shadows, blur, gaps; sets border_size=1, rounding=0
-- Kills swww daemon for performance
local function enable_game_mode()
    -- Snapshot current values so disable_game_mode can restore them exactly.
    local snap_ok, snap = pcall(function()
        return {
            animations  = hl.config.animations.enabled,
            shadow      = hl.config.decoration.shadow.enabled,
            blur        = hl.config.decoration.blur.enabled,
            gaps_in     = hl.config.general.gaps_in,
            gaps_out    = hl.config.general.gaps_out,
            border_size = hl.config.general.border_size,
            rounding    = hl.config.decoration.rounding,
        }
    end)
    if snap_ok then
        game_mode_saved = snap
    end

    local success, err = pcall(function()
        hl.config.animations.enabled = false
        hl.config.decoration.shadow.enabled = false
        hl.config.decoration.blur.enabled = false
        hl.config.general.gaps_in = 0
        hl.config.general.gaps_out = 0
        hl.config.general.border_size = 1
        hl.config.decoration.rounding = 0
    end)

    if not success then
        notify.error("Game mode: Failed to apply settings", tostring(err))
    end

    -- Force opacity 1 on every window (active/inactive/fullscreen) for perf.
    -- " override" sets absolute instead of multiplied; see window-rules.
    if not game_mode_opacity_rule then
        game_mode_opacity_rule = hl.window_rule({
            match = { class = "^(.*)$" },
            opacity = "1 override 1 override 1 override",
        })
    end

    -- Kill swww
    hl.exec_cmd("swww kill")

    -- Send notification
    notify.send({
        text = "Gamemode: enabled",
        icon = ICON,
        timeout = 2000
    })
end

---Disable game mode by restoring the snapshotted settings.
local function disable_game_mode()
    -- Restart swww daemon and re-set the wallpaper.
    hl.exec_cmd(string.format("swww-daemon --format xrgb && swww img '%s' &", WALLPAPER_PATH))
    helpers.sleep(0.1)

    -- Regenerate wallust colors from the current wallpaper.
    local wallpaper = require("user-functions.wallpaper")
    wallpaper.apply_wallust()
    helpers.sleep(0.5)

    -- Tear down the runtime opacity rule installed by enable_game_mode.
    if game_mode_opacity_rule and game_mode_opacity_rule.set_enabled then
        pcall(function() game_mode_opacity_rule:set_enabled(false) end)
        game_mode_opacity_rule = nil
    end

    -- Restore config values from the snapshot if we have one.
    if game_mode_saved then
        local saved = game_mode_saved
        pcall(function()
            hl.config.animations.enabled = saved.animations
            hl.config.decoration.shadow.enabled = saved.shadow
            hl.config.decoration.blur.enabled = saved.blur
            hl.config.general.gaps_in = saved.gaps_in
            hl.config.general.gaps_out = saved.gaps_out
            hl.config.general.border_size = saved.border_size
            hl.config.decoration.rounding = saved.rounding
        end)
        game_mode_saved = nil
    end

    refresh.refresh_ui()

    notify.send({
        text = "Gamemode: disabled",
        icon = ICON,
        timeout = 2000,
    })
end

---Toggle game mode on/off
-- When enabling: disables animations, shadows, blur, gaps; kills swww
-- When disabling: restarts swww and reloads config
-- @function game_mode
function window.game_mode()
    local success, err = pcall(function()
        if is_animations_enabled() then
            enable_game_mode()
        else
            disable_game_mode()
        end
    end)

    if (not success) then
        local notify = require("utils.notify")
        notify.error("Game mode toggle failed", tostring(err))
    end
end

-- ============================================
-- LAYOUT TOGGLE
-- ============================================

---Get the current layout from Hyprland
-- @return string The current layout name ("master" or "dwindle")
local function get_current_layout()
    local success, layout = pcall(function()
        return hl.config.general.layout
    end)

    if not success then
        return "dwindle"
    end

    return layout
end

---Switch to dwindle layout and rebind J/K/O for window cycling.
local function switch_to_dwindle()
    hl.unbind("SUPER + J")
    hl.unbind("SUPER + K")
    hl.unbind("SUPER + O")

    local ok, err = pcall(function()
        hl.config.general.layout = "dwindle"
    end)
    if not ok then
        notify.error("Failed to switch layout", tostring(err))
    end

    hl.bind("SUPER + J", hl.dsp.window.cycle_next())
    hl.bind("SUPER + K", hl.dsp.window.cycle_next({ prev = true }))
    hl.bind("SUPER + O", hl.dsp.layout("togglesplit"))

    notify.send({
        text = "Dwindle Layout",
        icon = ICON,
        timeout = 2000,
    })
end

---Switch to master layout and rebind J/K for master-layout cycling.
local function switch_to_master()
    hl.unbind("SUPER + J")
    hl.unbind("SUPER + K")
    hl.unbind("SUPER + O")

    local ok, err = pcall(function()
        hl.config.general.layout = "master"
    end)
    if not ok then
        notify.error("Failed to switch layout", tostring(err))
    end

    hl.bind("SUPER + J", hl.dsp.layout("cyclenext"))
    hl.bind("SUPER + K", hl.dsp.layout("cycleprev"))

    notify.send({
        text = "Master Layout",
        icon = ICON,
        timeout = 2000,
    })
end

---Toggle between master and dwindle layouts
-- Automatically switches layout and rebinds navigation keys appropriately
-- @function layout_toggle
function window.layout_toggle()
    local success, err = pcall(function()
        local current_layout = get_current_layout()

        if current_layout == "master" then
            switch_to_dwindle()
        else
            switch_to_master()
        end
    end)

    if (not success) then
        local notify = require("utils.notify")
        notify.error("Layout toggle failed", tostring(err))
    end
end

return window
