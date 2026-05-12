-- Settings configuration
-- Based on UserSettings.conf and UserDecorations.conf

local colors = require("wallust-colors")

hl.config({
    dwindle = {
        preserve_split = true,
        special_scale_factor = 0.8,
    },
    master = {
        new_status = "master",
        new_on_top = 1,
        mfact = 0.5,
    },
    general = {
        resize_on_border = true,
        layout = "dwindle",
        border_size = 2,
        gaps_in = 2,
        gaps_out = 4,
        ["col.active_border"] = colors.color12,
        ["col.inactive_border"] = colors.color10,
    },
    input = {
        kb_layout = "us",
        repeat_rate = 50,
        repeat_delay = 300,
        sensitivity = 0,
        numlock_by_default = true,
        left_handed = false,
        follow_mouse = 0,
        float_switch_override_focus = false,
        natural_scroll = true,
        touchpad = {
            disable_while_typing = true,
            clickfinger_behavior = false,
            middle_button_emulation = false,
            tap_to_click = true,
            drag_lock = false,
            natural_scroll = true,
        },
    },
    gestures = {
        workspace_swipe_distance = 500,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.3,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = false,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        enable_swallow = false,
        swallow_regex = "^(kitty)$",
        focus_on_activate = false,
        initial_workspace_tracking = 0,
        middle_click_paste = false,
        enable_anr_dialog = true,
        anr_missed_pings = 15,
        allow_session_lock_restore = true,
    },
    debug = {
        vfr = true,
        disable_logs = true,
    },
    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },
    xwayland = {
        enabled = true,
        force_zero_scaling = true,
    },
    render = {
        direct_scanout = 0,
    },
    cursor = {
        sync_gsettings_theme = true,
        no_hardware_cursors = 2,
        enable_hyprcursor = true,
        warp_on_change_workspace = 2,
        no_warps = true,
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,
        dim_inactive = false,
        dim_strength = 0.1,
        dim_special = 0.5,
        shadow = {
            enabled = false,
            range = 3,
            render_power = 1,
            color = colors.color12,
            color_inactive = colors.color10,
        },
        blur = {
            enabled = false,
            size = 6,
            passes = 2,
            ignore_opacity = true,
            new_optimizations = true,
            special = true,
            popups = true,
        },
    },
    group = {
        ["col.border_active"] = colors.color15,
        groupbar = {
            ["col.active"] = colors.color0,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
