---
-- Notification Helper Utilities
--
-- Wraps notify-send so notifications go through the user's desktop
-- notification daemon (swaync) — that's where the curated icon paths
-- in ~/.config/swaync/icons live.
--
-- Note: hl.notification.create() draws Hyprland's lightweight in-corner
-- popup and only honors a fixed keyword set for icons (warning|info|hint|
-- error|confused|ok). Use this module instead when you want themed icons.
--
-- @module notify
-- @author Brett
-- @license MIT

local notify = {}

-- ============================================
-- ICON CONFIGURATION
-- ============================================

local SWAYNC_ICONS = os.getenv("HOME") .. "/.config/swaync/icons"
local SWAYNC_IMAGES = os.getenv("HOME") .. "/.config/swaync/images"

local ICONS = {
    volume = {
        high = SWAYNC_ICONS .. "/volume-high.png",
        medium = SWAYNC_ICONS .. "/volume-mid.png",
        low = SWAYNC_ICONS .. "/volume-low.png",
        muted = SWAYNC_ICONS .. "/volume-mute.png",
        mic_muted = SWAYNC_ICONS .. "/microphone-mute.png",
        mic_on = SWAYNC_ICONS .. "/microphone.png"
    },
    brightness = {
        screen = SWAYNC_ICONS .. "/brightness-100.png",
        keyboard = SWAYNC_ICONS .. "/brightness-100.png"
    },
    system = {
        error = SWAYNC_IMAGES .. "/note.png",
        info = SWAYNC_IMAGES .. "/ja.png",
        success = SWAYNC_IMAGES .. "/ja.png",
        warning = SWAYNC_IMAGES .. "/note.png",
        screenshot = SWAYNC_ICONS .. "/picture.png",
        lock = SWAYNC_IMAGES .. "/ja.png",
        logout = SWAYNC_IMAGES .. "/ja.png"
    }
}

-- ============================================
-- CORE
-- ============================================

---Single-quote a string for safe shell embedding.
local function shquote(s)
    return "'" .. tostring(s):gsub("'", [['\'']]) .. "'"
end

---Send a desktop notification via notify-send (routed to swaync).
---@param opts table {text:string, icon?:string, timeout?:number, title?:string, urgency?:string, hints?:string[]}
function notify.send(opts)
    opts = opts or {}

    local text = opts.text or ""
    local title = opts.title
    local icon = opts.icon
    local timeout = opts.timeout or 3000
    local urgency = opts.urgency  -- low | normal | critical

    local cmd = { "notify-send", "-e" }
    table.insert(cmd, "-t " .. tonumber(timeout))

    if icon and icon ~= "" then
        table.insert(cmd, "-i " .. shquote(icon))
    end

    if urgency then
        table.insert(cmd, "-u " .. shquote(urgency))
    end

    -- Extra hints, e.g. { "int:value:75", "string:x-canonical-private-synchronous:vol" }
    for _, hint in ipairs(opts.hints or {}) do
        table.insert(cmd, "-h " .. shquote(hint))
    end

    -- notify-send takes <summary> and optional <body>.
    -- If a title is provided, summary=title and body=text; otherwise summary=text.
    if title then
        table.insert(cmd, shquote(title))
        table.insert(cmd, shquote(text))
    else
        table.insert(cmd, shquote(text))
    end

    hl.exec_cmd(table.concat(cmd, " "))
end

-- ============================================
-- VOLUME NOTIFICATIONS
-- ============================================

---Show a volume change notification
---@param volume number The current volume level (0-100)
---@param muted boolean Whether the volume is muted
function notify.volume(volume, muted)
    local icon
    local text

    if muted then
        icon = ICONS.volume.muted
        text = "Volume: Muted"
    else
        if volume >= 70 then
            icon = ICONS.volume.high
        elseif volume >= 30 then
            icon = ICONS.volume.medium
        else
            icon = ICONS.volume.low
        end
        text = string.format("Volume: %d%%", volume)
    end

    notify.send({
        text = text,
        icon = icon,
        timeout = 2000,
        urgency = "low",
        hints = {
            "int:value:" .. (muted and 0 or volume),
            "string:x-canonical-private-synchronous:volume_notif",
            "boolean:SWAYNC_BYPASS_DND:true",
        },
    })
end

---Show a microphone mute state notification
---@param muted boolean Whether the microphone is muted
function notify.mic(muted)
    notify.send({
        text = muted and "Microphone Muted" or "Microphone On",
        icon = muted and ICONS.volume.mic_muted or ICONS.volume.mic_on,
        timeout = 2000,
    })
end

-- ============================================
-- BRIGHTNESS NOTIFICATIONS
-- ============================================

---Show a screen brightness change notification
---@param brightness number The current brightness level (0-100)
function notify.brightness(brightness)
    notify.send({
        text = string.format("Brightness: %d%%", brightness),
        icon = ICONS.brightness.screen,
        timeout = 2000,
        urgency = "low",
        hints = {
            "int:value:" .. brightness,
            "string:x-canonical-private-synchronous:brightness_notif",
            "boolean:SWAYNC_BYPASS_DND:true",
        },
    })
end

---Show a keyboard brightness change notification
---@param brightness number The current keyboard brightness level (0-100)
function notify.kbd_brightness(brightness)
    notify.send({
        text = string.format("Keyboard: %d%%", brightness),
        icon = ICONS.brightness.keyboard,
        timeout = 2000,
    })
end

-- ============================================
-- SYSTEM NOTIFICATIONS
-- ============================================

---Show a screenshot notification
---@param message string The message to display
function notify.screenshot(message)
    notify.send({
        text = message or "Screenshot saved",
        icon = ICONS.system.screenshot,
        timeout = 3000,
    })
end

---Show a lock screen notification
function notify.lock()
    notify.send({
        text = "Screen locked",
        icon = ICONS.system.lock,
        timeout = 2000,
    })
end

---Show an error notification
---@param message string The error message
---@param details string|nil Optional error details
function notify.error(message, details)
    local text = message
    if details and details ~= "" then
        text = text .. " (" .. tostring(details) .. ")"
    end

    notify.send({
        text = text,
        icon = ICONS.system.error,
        timeout = 5000,
        urgency = "critical",
    })
end

---Show a success notification
---@param message string The success message
function notify.success(message)
    notify.send({
        text = message,
        icon = ICONS.system.success,
        timeout = 2000,
    })
end

---Show an informational notification
---@param message string The info message
function notify.info(message)
    notify.send({
        text = message,
        icon = ICONS.system.info,
        timeout = 3000,
    })
end

return notify
