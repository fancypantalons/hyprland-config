-- Rofi menu primitives.
-- Replaces the kill-rofi/build-items/echo-pipe/exec_async/pcall/trim pattern
-- that appeared 10+ times across waybar, rofi, session, system, wallpaper modules.

local menu    = {}
local helpers = require("utils.helpers")

local MARKER = "👉"

-- Build the text piped into rofi and a set of display→original mappings.
-- items: array of strings OR { label, icon } tables.
-- current: label of the item to mark with MARKER (optional).
-- Returns: items_string, current_row (0-based)
local function build_items(items, current)
    local lines = {}
    local current_row = 0

    for i, item in ipairs(items) do
        local label, icon
        if type(item) == "table" then
            label, icon = item.label, item.icon
        else
            label = tostring(item)
        end

        local display = (label == current) and (MARKER .. " " .. label) or label
        if label == current then current_row = i - 1 end

        table.insert(lines, icon and (display .. "\0icon\x1f" .. icon) or display)
    end

    return table.concat(lines, "\n"), current_row
end

-- Strip any leading MARKER from a rofi result string.
local function strip_marker(s)
    return (s or ""):gsub("^" .. MARKER .. "%s*", "")
end

---Show a rofi dmenu picker.
--
-- opts fields:
--   theme        string   Path to .rasi config (required)
--   items        table    Array of strings or { label, icon } tables
--   current      string   Item to mark + jump to (optional)
--   message      string   -mesg hint text (optional)
--   extra        string   Extra raw flags appended to rofi (optional)
--   custom_binds table    { { key="Ctrl+Delete", name="delete" }, ... }
--                         Maps to -kb-custom-N; exit codes 10, 11, ...
--
-- callback(choice, action)
--   choice: selected label (marker stripped), nil if cancelled
--   action: nil for normal pick, or .name string for a custom bind
function menu.pick(opts, cb)
    hl.exec_cmd("pkill -x rofi 2>/dev/null || true")

    local items     = opts.items or {}
    local binds     = opts.custom_binds or {}
    local items_str, current_row = build_items(items, opts.current)

    -- Write items to a temp file to avoid NUL byte issues in shell quoting.
    local tmpfile = "/tmp/hypr-menu-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999)) .. ".txt"
    helpers.write_file(tmpfile, items_str)

    local parts = {
        "cat", helpers.shquote(tmpfile), "|",
        "rofi", "-i", "-dmenu",
        "-config", helpers.shquote(opts.theme),
    }

    if opts.message then
        table.insert(parts, "-mesg " .. helpers.shquote(opts.message))
    end

    if current_row > 0 then
        table.insert(parts, "-selected-row " .. current_row)
    end

    for i, bind in ipairs(binds) do
        table.insert(parts, string.format("-kb-custom-%d %s", i, helpers.shquote(bind.key)))
    end

    if opts.extra then
        table.insert(parts, opts.extra)
    end

    helpers.exec_async(table.concat(parts, " "), function(exit_code, raw)
        os.remove(tmpfile)
        pcall(function()
            local choice = helpers.trim(raw or "")

            if exit_code == 1 or choice == "" then
                cb(nil, nil)
                return
            end

            choice = strip_marker(choice)

            local action = nil
            if exit_code >= 10 then
                local bind = binds[exit_code - 9]
                if bind then action = bind.name end
            end

            cb(choice, action)
        end)
    end)
end

---Show a rofi text-input prompt (no items list).
--
-- opts fields:
--   theme   string  Path to .rasi config (required)
--   message string  -mesg hint text (optional)
--   prompt  string  Prompt label (optional)
--
-- callback(text)  nil if cancelled or empty
function menu.input(opts, cb)
    hl.exec_cmd("pkill -x rofi 2>/dev/null || true")

    local parts = {
        "echo ''", "|",
        "rofi", "-dmenu",
        "-config", helpers.shquote(opts.theme),
    }

    if opts.message then
        table.insert(parts, "-mesg " .. helpers.shquote(opts.message))
    end

    if opts.prompt then
        table.insert(parts, "-p " .. helpers.shquote(opts.prompt))
    end

    helpers.exec_async(table.concat(parts, " "), function(exit_code, raw)
        pcall(function()
            if exit_code == 1 then cb(nil); return end
            local text = helpers.trim(raw or "")
            cb(text ~= "" and text or nil)
        end)
    end)
end

return menu
