-- Window management: kill, game mode, layout toggle.

local window  = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local icons   = require("utils.icons")

-- Runtime state for game mode (module-level; survives across calls in a session).
local game_mode_opacity_rule = nil
local game_mode_saved        = nil

-- ============================================
-- KILL ACTIVE
-- ============================================

function window.kill_active()
    helpers.safe_call("Kill active process failed", function()
        local w = hl.get_active_window()
        if not w or not w.pid or w.pid == 0 then
            notify.error("No active window found"); return
        end
        helpers.exec("kill " .. tostring(w.pid))
    end)
end

-- ============================================
-- GAME MODE
-- ============================================

local function enable_game_mode()
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
    if snap_ok then game_mode_saved = snap end

    pcall(function()
        hl.config.animations.enabled          = false
        hl.config.decoration.shadow.enabled   = false
        hl.config.decoration.blur.enabled     = false
        hl.config.general.gaps_in             = 0
        hl.config.general.gaps_out            = 0
        hl.config.general.border_size         = 1
        hl.config.decoration.rounding         = 0
    end)

    if not game_mode_opacity_rule then
        game_mode_opacity_rule = hl.window_rule({
            match   = { class = "^(.*)$" },
            opacity = "1 override 1 override 1 override",
        })
    end

    hl.exec_cmd("swww kill")
    notify.send({ text = "Gamemode: on", icon = icons.system.info, timeout = 2000 })
end

local function disable_game_mode()
    local wallpaper_path = os.getenv("HOME") .. "/.config/rofi/.current_wallpaper"

    helpers.exec_async(
        string.format("swww-daemon --format xrgb && swww img %s", helpers.shquote(wallpaper_path)),
        function(_, _)
            pcall(function()
                require("user-functions.wallpaper").apply_wallust()

                if game_mode_opacity_rule and game_mode_opacity_rule.set_enabled then
                    pcall(function() game_mode_opacity_rule:set_enabled(false) end)
                    game_mode_opacity_rule = nil
                end

                if game_mode_saved then
                    local s = game_mode_saved
                    pcall(function()
                        hl.config.animations.enabled          = s.animations
                        hl.config.decoration.shadow.enabled   = s.shadow
                        hl.config.decoration.blur.enabled     = s.blur
                        hl.config.general.gaps_in             = s.gaps_in
                        hl.config.general.gaps_out            = s.gaps_out
                        hl.config.general.border_size         = s.border_size
                        hl.config.decoration.rounding         = s.rounding
                    end)
                    game_mode_saved = nil
                end

                require("utils.refresh").refresh_ui()
                notify.send({ text = "Gamemode: off", icon = icons.system.info, timeout = 2000 })
            end)
        end
    )
end

function window.game_mode()
    helpers.safe_call("Game mode toggle failed", function()
        local ok, enabled = pcall(function() return hl.config.animations.enabled end)
        if (ok and enabled) or not ok then
            enable_game_mode()
        else
            disable_game_mode()
        end
    end)
end

-- ============================================
-- LAYOUT TOGGLE
-- ============================================

local function switch_to_dwindle()
    hl.unbind("SUPER + J"); hl.unbind("SUPER + K"); hl.unbind("SUPER + O")
    pcall(function() hl.config.general.layout = "dwindle" end)
    hl.bind("SUPER + J", hl.dsp.window.cycle_next())
    hl.bind("SUPER + K", hl.dsp.window.cycle_next({ prev = true }))
    hl.bind("SUPER + O", hl.dsp.layout("togglesplit"))
    notify.send({ text = "Dwindle layout", icon = icons.system.info, timeout = 2000 })
end

local function switch_to_master()
    hl.unbind("SUPER + J"); hl.unbind("SUPER + K"); hl.unbind("SUPER + O")
    pcall(function() hl.config.general.layout = "master" end)
    hl.bind("SUPER + J", hl.dsp.layout("cyclenext"))
    hl.bind("SUPER + K", hl.dsp.layout("cycleprev"))
    notify.send({ text = "Master layout", icon = icons.system.info, timeout = 2000 })
end

function window.layout_toggle()
    helpers.safe_call("Layout toggle failed", function()
        local ok, layout = pcall(function() return hl.config.general.layout end)
        if ok and layout == "master" then switch_to_dwindle() else switch_to_master() end
    end)
end

return window
