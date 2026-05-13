-- Waybar style and layout selectors.

local waybar  = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local menu    = require("utils.menu")

local HOME             = os.getenv("HOME")
local WAYBAR_DIR       = HOME .. "/.config/waybar"
local STYLE_DIR        = WAYBAR_DIR .. "/style"
local LAYOUT_DIR       = WAYBAR_DIR .. "/configs"
local STYLE_LINK       = WAYBAR_DIR .. "/style.css"
local CONFIG_LINK      = WAYBAR_DIR .. "/config"
local ROFI_STYLE_CFG   = HOME .. "/.config/rofi/config-waybar-style.rasi"
local ROFI_LAYOUT_CFG  = HOME .. "/.config/rofi/config-waybar-layout.rasi"

local STYLE_MSG  = "NOTE: Some styles are not fully compatible with all layouts"
local LAYOUT_MSG = "NOTE: Some layouts are not fully compatible with all styles"

-- ============================================
-- INTERNAL HELPERS
-- ============================================

local function readlink(path)
    local r = helpers.exec("readlink -f " .. helpers.shquote(path) .. " 2>/dev/null")
    return r.success and helpers.trim(r.stdout) or nil
end

local function current_style()
    local p = readlink(STYLE_LINK)
    return p and p:match("([^/]+)%.css$") or nil
end

local function current_layout()
    local p = readlink(CONFIG_LINK)
    return p and p:match("([^/]+)$") or nil
end

local function list_dir(dir, pattern)
    local r = helpers.exec(string.format(
        "find -L %s -maxdepth 1 -type f -name %s -printf '%%f\\n' 2>/dev/null | sort",
        helpers.shquote(dir), helpers.shquote(pattern)
    ))
    if not r.success then return {} end
    local items = {}
    for line in r.stdout:gmatch("[^\r\n]+") do table.insert(items, line) end
    return items
end

local function apply_link(target, link)
    hl.exec_cmd(string.format("ln -sf %s %s", helpers.shquote(target), helpers.shquote(link)))
    require("utils.refresh").refresh_ui()
end

-- ============================================
-- PUBLIC
-- ============================================

function waybar.select_style()
    local styles = list_dir(STYLE_DIR, "*.css")
    if #styles == 0 then notify.error("No styles found", STYLE_DIR); return end

    -- Strip .css suffix for display.
    local labels = {}
    for _, f in ipairs(styles) do table.insert(labels, f:match("(.+)%.css$") or f) end

    menu.pick({
        theme   = ROFI_STYLE_CFG,
        items   = labels,
        current = current_style(),
        message = STYLE_MSG,
    }, function(choice, _)
        if not choice then return end
        apply_link(STYLE_DIR .. "/" .. choice .. ".css", STYLE_LINK)
    end)
end

function waybar.select_layout()
    local layouts = list_dir(LAYOUT_DIR, "*")
    if #layouts == 0 then notify.error("No layouts found", LAYOUT_DIR); return end

    menu.pick({
        theme   = ROFI_LAYOUT_CFG,
        items   = layouts,
        current = current_layout(),
        message = LAYOUT_MSG,
    }, function(choice, _)
        if not choice then return end
        if choice == "no panel" then
            hl.exec_cmd("pkill waybar 2>/dev/null || true")
        else
            apply_link(LAYOUT_DIR .. "/" .. choice, CONFIG_LINK)
        end
    end)
end

return waybar
