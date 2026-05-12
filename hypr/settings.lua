-- Settings configuration
-- Based on UserSettings.conf and UserDecorations.conf

-- Load wallust colors for dynamic theming
local colors = require("wallust-colors")

-- dwindle layout settings
hl.config.dwindle.preserve_split = true
hl.config.dwindle.special_scale_factor = 0.8

-- master layout settings
hl.config.master.new_status = "master"
hl.config.master.new_on_top = 1
hl.config.master.mfact = 0.5

-- general settings
hl.config.general.resize_on_border = true
hl.config.general.layout = "dwindle"
hl.config.general.border_size = 2
hl.config.general.gaps_in = 2
hl.config.general.gaps_out = 4
hl.config.general["col.active_border"] = colors.color12
hl.config.general["col.inactive_border"] = colors.color10

-- input settings
hl.config.input.kb_layout = "us"
hl.config.input.repeat_rate = 50
hl.config.input.repeat_delay = 300
hl.config.input.sensitivity = 0
hl.config.input.numlock_by_default = true
hl.config.input.left_handed = false
hl.config.input.follow_mouse = 0
hl.config.input.float_switch_override_focus = false
hl.config.input.natural_scroll = true

-- touchpad settings
hl.config.input.touchpad.disable_while_typing = true
hl.config.input.touchpad.clickfinger_behavior = false
hl.config.input.touchpad.middle_button_emulation = false
hl.config.input.touchpad.tap_to_click = true
hl.config.input.touchpad.drag_lock = false
hl.config.input.touchpad.natural_scroll = true

-- gesture settings
hl.config.gestures.workspace_swipe_distance = 500
hl.config.gestures.workspace_swipe_invert = true
hl.config.gestures.workspace_swipe_min_speed_to_force = 30
hl.config.gestures.workspace_swipe_cancel_ratio = 0.3
hl.config.gestures.workspace_swipe_create_new = true
hl.config.gestures.workspace_swipe_forever = false

-- misc settings
hl.config.misc.disable_hyprland_logo = true
hl.config.misc.disable_splash_rendering = true
hl.config.misc.mouse_move_enables_dpms = true
hl.config.misc.enable_swallow = false
hl.config.misc.swallow_regex = "^(kitty)$"
hl.config.misc.focus_on_activate = false
hl.config.misc.initial_workspace_tracking = 0
hl.config.misc.middle_click_paste = false
hl.config.misc.enable_anr_dialog = true
hl.config.misc.anr_missed_pings = 15
hl.config.misc.allow_session_lock_restore = true

-- debug settings
hl.config.debug.vfr = true
hl.config.debug.disable_logs = true

-- binds settings
hl.config.binds.workspace_back_and_forth = true
hl.config.binds.allow_workspace_cycles = true
hl.config.binds.pass_mouse_when_bound = false

-- xwayland settings
hl.config.xwayland.enabled = true
hl.config.xwayland.force_zero_scaling = true

-- render settings
hl.config.render.direct_scanout = 0

-- cursor settings
hl.config.cursor.sync_gsettings_theme = true
hl.config.cursor.no_hardware_cursors = 2
hl.config.cursor.enable_hyprcursor = true
hl.config.cursor.warp_on_change_workspace = 2
hl.config.cursor.no_warps = true

-- decoration settings
hl.config.decoration.rounding = 10
hl.config.decoration.active_opacity = 1.0
hl.config.decoration.inactive_opacity = 0.9
hl.config.decoration.fullscreen_opacity = 1.0
hl.config.decoration.dim_inactive = false
hl.config.decoration.dim_strength = 0.1
hl.config.decoration.dim_special = 0.5

-- shadow settings
hl.config.decoration.shadow.enabled = false
hl.config.decoration.shadow.range = 3
hl.config.decoration.shadow.render_power = 1
hl.config.decoration.shadow.color = colors.color12
hl.config.decoration.shadow.color_inactive = colors.color10

-- blur settings
hl.config.decoration.blur.enabled = false
hl.config.decoration.blur.size = 6
hl.config.decoration.blur.passes = 2
hl.config.decoration.blur.ignore_opacity = true
hl.config.decoration.blur.new_optimizations = true
hl.config.decoration.blur.special = true
hl.config.decoration.blur.popups = true

-- group settings
hl.config.group["col.border_active"] = colors.color15
hl.config.group.groupbar.col.active = colors.color0

-- Define gesture
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
