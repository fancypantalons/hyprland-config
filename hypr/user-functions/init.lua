---
-- User Functions Module Loader
-- Loads and initializes all user-function submodules
--
-- This module creates the `user` namespace and loads all submodules
-- so they can be accessed via: user = require("user-functions")
--
-- @module user-functions
-- @author Brett
-- @license MIT

local user = {}

-- ============================================
-- MODULE LOADING WITH ERROR HANDLING
-- ============================================

local function load_module(name)
    local ok, module = pcall(require, "user-functions." .. name)
    
    if (not ok) then
        print("Warning: Failed to load user-functions." .. name .. ": " .. tostring(module))
        return {}
    end
    
    return module
end

-- Load all submodules
user.audio = load_module("audio")
user.display = load_module("display")
user.session = load_module("session")
user.window = load_module("window")
user.system = load_module("system")
user.wallpaper = load_module("wallpaper")
user.rofi = load_module("rofi")
user.input = load_module("input")
user.waybar = load_module("waybar")

return user
