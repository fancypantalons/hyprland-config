---
-- Waybar Control Functions
-- Provides rofi menus for selecting waybar styles and layouts
--
-- All functions use baked-in values and show notifications via the notify module
--
-- @module user-functions.waybar
-- @author Brett
-- @license MIT

local waybar = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local HOME = os.getenv("HOME")
local WAYBAR_DIR = HOME .. "/.config/waybar"
local WAYBAR_STYLE_DIR = WAYBAR_DIR .. "/style"
local WAYBAR_LAYOUT_DIR = WAYBAR_DIR .. "/configs"
local WAYBAR_STYLE_LINK = WAYBAR_DIR .. "/style.css"
local WAYBAR_CONFIG_LINK = WAYBAR_DIR .. "/config"
local ROFI_STYLE_CONFIG = HOME .. "/.config/rofi/config-waybar-style.rasi"
local ROFI_LAYOUT_CONFIG = HOME .. "/.config/rofi/config-waybar-layout.rasi"

local STYLE_MSG = " 🎌 NOTE: Some waybar STYLES NOT fully compatible with some LAYOUTS"
local LAYOUT_MSG = " 🎌 NOTE: Some waybar LAYOUT NOT fully compatible with some STYLES"
local MARKER = "👉"

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Get the current style from the symlink
-- @return string|nil The current style name, or nil if not found
local function get_current_style()
    local result = helpers.exec("readlink -f '" .. WAYBAR_STYLE_LINK .. "' 2>/dev/null")

    if not result.success or result.stdout == "" then
        return nil
    end

    local basename = result.stdout:gsub("%s+$", "")
    local style_name = basename:match("([^/]+)%.css$")

    return style_name
end

---Get the current layout from the symlink
-- @return string|nil The current layout name, or nil if not found
local function get_current_layout()
    local result = helpers.exec("readlink -f '" .. WAYBAR_CONFIG_LINK .. "' 2>/dev/null")

    if not result.success or result.stdout == "" then
        return nil
    end

    local layout_name = result.stdout:gsub("%s+$", ""):match("([^/]+)$")

    return layout_name
end

---Get list of available styles
-- @return table Array of style names (without .css extension)
local function get_available_styles()
    local styles = {}
    local result = helpers.exec("find -L '" .. WAYBAR_STYLE_DIR .. "' -maxdepth 1 -type f -name '*.css' -exec basename {} .css \\; 2>/dev/null | sort")

    if not result.success then
        return styles
    end

    for line in result.stdout:gmatch("[^\r\n]+") do
        table.insert(styles, line)
    end

    return styles
end

---Get list of available layouts
-- @return table Array of layout names
local function get_available_layouts()
    local layouts = {}
    local result = helpers.exec("find -L '" .. WAYBAR_LAYOUT_DIR .. "' -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null | sort")

    if not result.success then
        return layouts
    end

    for line in result.stdout:gmatch("[^\r\n]+") do
        table.insert(layouts, line)
    end

    return layouts
end

---Apply a style by updating the symlink
-- @param style_name string The style name to apply
local function apply_style(style_name)
    local style_path = WAYBAR_STYLE_DIR .. "/" .. style_name .. ".css"
    hl.exec_cmd("ln -sf '" .. style_path .. "' '" .. WAYBAR_STYLE_LINK .. "'")

    -- Call refresh to apply changes
    local refresh = require("utils.refresh")
    refresh.refresh_ui()
end

---Apply a layout by updating the symlink
-- @param layout_name string The layout name to apply
local function apply_layout(layout_name)
    local layout_path = WAYBAR_LAYOUT_DIR .. "/" .. layout_name
    hl.exec_cmd("ln -sf '" .. layout_path .. "' '" .. WAYBAR_CONFIG_LINK .. "'")

    -- Call refresh to apply changes
    local refresh = require("utils.refresh")
    refresh.refresh_ui()
end

---Kill rofi if running
local function kill_rofi()
    hl.exec_cmd("pkill rofi 2>/dev/null || true")
end

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

---Show a rofi menu for selecting waybar style
-- Displays available styles from ~/.config/waybar/style/
-- Marks the current style with an indicator
-- Applies the selected style and refreshes the UI
-- @function select_style
function waybar.select_style()
    local notify = require("utils.notify")

    kill_rofi()

    local styles = get_available_styles()

    if (#styles == 0) then
        notify.error("No styles found", "Check " .. WAYBAR_STYLE_DIR)

        return
    end

    local current_style = get_current_style()
    local menu_items = {}
    local default_row = 0

    for i, style in ipairs(styles) do
        if (style == current_style) then
            table.insert(menu_items, MARKER .. " " .. style)
            default_row = i - 1
        else
            table.insert(menu_items, style)
        end
    end

    local menu_input = table.concat(menu_items, "\n")
    local rofi_cmd = string.format(
        "echo '%s' | rofi -i -dmenu -config '%s' -mesg '%s' -selected-row %d",
        menu_input:gsub("'", "'\"'\"'"),
        ROFI_STYLE_CONFIG,
        STYLE_MSG,
        default_row
    )

    helpers.exec_async(rofi_cmd, function(_, choice)
        pcall(function()
            if choice == nil or choice == "" then
                return
            end

            choice = choice:gsub("%s+$", "")

            if (choice == "") then
                return
            end

            choice = choice:gsub("^" .. MARKER .. " ", "")
            apply_style(choice)
        end)
    end)
end

---Show a rofi menu for selecting waybar layout
-- Displays available layouts from ~/.config/waybar/configs/
-- Marks the current layout with an indicator
-- Applies the selected layout and refreshes the UI
-- Special handling for "no panel" option to kill waybar
-- @function select_layout
function waybar.select_layout()
    local notify = require("utils.notify")

    kill_rofi()

    local layouts = get_available_layouts()

    if (#layouts == 0) then
        notify.error("No layouts found", "Check " .. WAYBAR_LAYOUT_DIR)

        return
    end

    local current_layout = get_current_layout()
    local menu_items = {}
    local default_row = 0

    for i, layout in ipairs(layouts) do
        if (layout == current_layout) then
            table.insert(menu_items, MARKER .. " " .. layout)
            default_row = i - 1
        else
            table.insert(menu_items, layout)
        end
    end

    local menu_input = table.concat(menu_items, "\n")
    local rofi_cmd = string.format(
        "echo '%s' | rofi -i -dmenu -config '%s' -mesg '%s' -selected-row %d",
        menu_input:gsub("'", "'\"'\"'"),
        ROFI_LAYOUT_CONFIG,
        LAYOUT_MSG,
        default_row
    )

    helpers.exec_async(rofi_cmd, function(_, choice)
        pcall(function()
            if choice == nil or choice == "" then
                return
            end

            choice = choice:gsub("%s+$", "")

            if (choice == "") then
                return
            end

            choice = choice:gsub("^" .. MARKER .. " ", "")

            if (choice == "no panel") then
                hl.exec_cmd("pkill waybar 2>/dev/null || true")
            else
                apply_layout(choice)
            end
        end)
    end)
end

return waybar
