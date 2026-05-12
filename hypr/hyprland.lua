-- Hyprland 0.55+ Lua configuration
-- Migrated from 0.54 hyprlang config

-- Base config directory for relative paths
configDir = os.getenv("HOME") .. "/.config/hypr"

-- ============================================
-- MONITOR CONFIGURATION
-- Based on monitors.conf
-- ============================================

-- Default fallback for any unconfigured monitor
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Integrated laptop monitor
hl.monitor({
  output = "desc:BOE",
  mode = "highres",
  position = "auto",
  scale = 1.6
})

-- Samsung monitor
hl.monitor({
  output = "desc:Samsung",
  mode = "highres",
  position = "-2560x0",
  scale = 1.5
})

-- ============================================
-- LOAD CONFIGURATION MODULES
-- ============================================

require("env")           -- Environment variables
require("settings")      -- General settings, decorations, input
require("animations")    -- Bezier curves and animations
require("devices")       -- Device-specific settings
require("window-rules")  -- Window and layer rules

-- Load user-functions namespace for use by binds and autostart
user = require("user-functions")

require("binds")         -- Keybindings
require("autostart")     -- Autostart applications


