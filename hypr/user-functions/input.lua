-- Keyboard layout switching.

local input   = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local icons   = require("utils.icons")
local state   = require("utils.state")

-- Patterns for devices to skip when switching layouts.
local IGNORE_PATTERNS = { "--(avrcp)", "Bluetooth Speaker" }

local function is_ignored(name)
    for _, pat in ipairs(IGNORE_PATTERNS) do
        if name:match(pat) then return true end
    end
    return false
end

-- Read kb_layout from Hyprland config and return as array, e.g. {"us","de"}.
local function configured_layouts()
    local raw = hl.get_config("input.kb_layout")
    if not raw or raw == "" then return nil, "Could not read kb_layout" end
    local layouts = {}
    for l in raw:gsub("%s", ""):gmatch("[^,]+") do
        table.insert(layouts, l)
    end
    return #layouts > 0 and layouts or nil, "No layouts configured"
end

-- Return (current_layout, all_layouts) or (nil, nil, err).
local function read_current_layout()
    local layouts, err = configured_layouts()
    if not layouts then return nil, nil, err end

    local default = layouts[1]
    local cached  = state.get("kb_layout", default)

    -- Validate cached value is still in the configured list.
    local valid = false
    for _, l in ipairs(layouts) do
        if l == cached then valid = true; break end
    end

    if not valid then
        cached = default
        state.set("kb_layout", default)
    end

    return cached, layouts
end

-- Async: get non-ignored keyboard device names from hyprctl.
local function get_keyboard_names(cb)
    helpers.exec_async(
        "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name' 2>/dev/null || echo ''",
        function(_, stdout)
            local keyboards = {}
            for line in stdout:gmatch("[^\r\n]+") do
                local name = helpers.trim(line)
                if name ~= "" and not is_ignored(name) then
                    table.insert(keyboards, name)
                end
            end
            cb(keyboards)
        end
    )
end

-- ============================================
-- PUBLIC
-- ============================================

function input.switch_layout()
    helpers.safe_call("Layout switch failed", function()
        local current, layouts, err = read_current_layout()
        if not current then notify.error("Failed to read layouts", err); return end

        local cur_idx = 1
        for i, l in ipairs(layouts) do
            if l == current then cur_idx = i; break end
        end

        local next_idx    = (cur_idx % #layouts) + 1
        local next_layout = layouts[next_idx]

        get_keyboard_names(function(keyboards)
            pcall(function()
                if #keyboards == 0 then notify.error("No keyboards found"); return end

                for _, kb in ipairs(keyboards) do
                    hl.exec_cmd(string.format("hyprctl switchxkblayout %s %d",
                        helpers.shquote(kb), next_idx - 1))
                end

                state.set("kb_layout", next_layout)
                notify.send({
                    text    = "Layout: " .. next_layout,
                    icon    = icons.system.info,
                    timeout = 2000,
                })
            end)
        end)
    end)
end

return input
