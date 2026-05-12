---
-- Input Control Functions
-- Provides keyboard layout switching and input device management
--
-- @module user-functions.input
-- @author Brett
-- @license MIT

local input = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local LAYOUT_CACHE_FILE = os.getenv("HOME") .. "/.cache/kb_layout"
local NOTIF_ICON = os.getenv("HOME") .. "/.config/swaync/images/ja.png"

-- Patterns to ignore when finding keyboards
local IGNORE_PATTERNS = {
    "--(avrcp)",
    "Bluetooth Speaker"
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Read configured keyboard layouts from UserSettings.conf
-- Parses the kb_layout = line and returns array of layout codes
-- @return table Array of layout codes (e.g., {"us", "de", "fr"})
-- @return string|nil Error message if failed
local function read_configured_layouts()
    local layouts_str = hl.get_config("input.kb_layout")

    if (not layouts_str) or (layouts_str == "") then
        return nil, "Could not read kb_layout from Hyprland"
    end

    -- Remove whitespace and split by comma
    layouts_str = layouts_str:gsub("%s", "")

    local layouts = {}
    for layout in layouts_str:gmatch("[^,]+") do
        table.insert(layouts, layout)
    end

    if #layouts == 0 then
        return nil, "No layouts found in settings"
    end

    return layouts
end

---Read current layout from cache file
-- @return string Current layout code, defaults to first configured layout
-- @return table Array of all configured layouts
-- @return string|nil Error message if failed
local function read_current_layout()
    local layouts, err = read_configured_layouts()

    if not layouts then
        return nil, nil, err
    end

    local default_layout = layouts[1]

    -- Read current layout from cache (or seed it with the default)
    local cached = helpers.read_file(LAYOUT_CACHE_FILE)
    if not cached then
        helpers.write_file(LAYOUT_CACHE_FILE, default_layout)
        return default_layout, layouts
    end

    local current_layout = cached:gsub("%s+$", "")

    -- Validate that the cached layout is in the configured list
    local valid = false
    for _, layout in ipairs(layouts) do
        if layout == current_layout then
            valid = true
            break
        end
    end

    if not valid then
        current_layout = default_layout
        helpers.write_file(LAYOUT_CACHE_FILE, default_layout)
    end

    return current_layout, layouts
end

---Get list of keyboard device names from hyprctl
-- Filters out devices matching ignore patterns
-- @return table Array of keyboard device names
local function get_keyboard_names()
    local result = helpers.exec("hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name' 2>/dev/null || echo ''")

    if not result.success or result.stdout == "" then
        return {}
    end

    local keyboards = {}

    for line in result.stdout:gmatch("[^\r\n]+") do
        local name = line:gsub("%s+$", "")

        if name ~= "" then
            -- Check if device should be ignored
            local ignored = false

            for _, pattern in ipairs(IGNORE_PATTERNS) do
                if name:match(pattern) then
                    ignored = true

                    break
                end
            end

            if not ignored then
                table.insert(keyboards, name)
            end
        end
    end

    return keyboards
end

---Check if a device name matches any ignore pattern
-- @param device_name string The device name to check
-- @return boolean True if device should be ignored
local function is_ignored(device_name)
    for _, pattern in ipairs(IGNORE_PATTERNS) do
        if device_name:match(pattern) then
            return true
        end
    end

    return false
end

-- ============================================
-- KEYBOARD LAYOUT SWITCHING
-- ============================================

---Switch to the next keyboard layout
-- Reads layouts from UserSettings.conf, cycles to next layout
-- Updates all non-ignored keyboards using hyprctl switchxkblayout
-- Saves new layout to cache file and shows notification
-- @function switch_layout
function input.switch_layout()
    local success, err = pcall(function()
        local current_layout, layouts, read_err = read_current_layout()

        if not current_layout then
            local notify = require("utils.notify")
            notify.error("Failed to read keyboard layouts", read_err)

            return
        end

        -- Find current index
        local current_index = 1

        for i, layout in ipairs(layouts) do
            if layout == current_layout then
                current_index = i

                break
            end
        end

        -- Calculate next index (wrap around)
        local next_index = (current_index % #layouts) + 1
        local new_layout = layouts[next_index]

        -- Get keyboard names
        local keyboards = get_keyboard_names()

        if #keyboards == 0 then
            local notify = require("utils.notify")
            notify.error("No keyboards found")

            return
        end

        -- Switch layout on all keyboards
        local error_found = false

        for _, keyboard_name in ipairs(keyboards) do
            if is_ignored(keyboard_name) then
                -- Skip ignored devices
            else
                local switch_result = helpers.exec(string.format("hyprctl switchxkblayout '%s' %d", keyboard_name, next_index - 1))

                if not switch_result.success then
                    error_found = true
                end
            end
        end

        if error_found then
            local notify = require("utils.notify")
            notify.error("Some keyboards failed to switch layout")
        end

        -- Save new layout to cache
        helpers.write_file(LAYOUT_CACHE_FILE, new_layout)

        -- Show notification
        notify.send({
            text = string.format("kb_layout: %s", new_layout),
            icon = NOTIF_ICON,
            timeout = 2000
        })
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Layout switch failed", tostring(err))
    end
end

return input
