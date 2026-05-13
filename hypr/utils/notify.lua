-- Notification helpers.
-- Routes all desktop notifications through notify-send → swaync.
-- hl.notification.create() is not used here because it only supports a fixed
-- keyword set for icons (warning|info|hint|error|confused|ok).

local notify = {}
local ICONS  = require("utils.icons")

-- ============================================
-- CORE
-- ============================================

local function shquote(s)
    return "'" .. tostring(s):gsub("'", [['\'']]) .. "'"
end

---Send a desktop notification via notify-send.
-- @param opts table {text, icon?, timeout?, title?, urgency?, hints?}
function notify.send(opts)
    opts = opts or {}

    local cmd = { "notify-send", "-e", "-t " .. tostring(opts.timeout or 3000) }

    if opts.icon and opts.icon ~= "" then
        table.insert(cmd, "-i " .. shquote(opts.icon))
    end

    if opts.urgency then
        table.insert(cmd, "-u " .. shquote(opts.urgency))
    end

    for _, hint in ipairs(opts.hints or {}) do
        table.insert(cmd, "-h " .. shquote(hint))
    end

    if opts.title then
        table.insert(cmd, shquote(opts.title))
        table.insert(cmd, shquote(opts.text or ""))
    else
        table.insert(cmd, shquote(opts.text or ""))
    end

    hl.exec_cmd(table.concat(cmd, " "))
end

-- ============================================
-- GENERIC SEVERITY HELPERS
-- ============================================

function notify.error(message, details)
    local text = message
    if details and details ~= "" then
        text = text .. " (" .. tostring(details) .. ")"
    end
    notify.send({ text = text, icon = ICONS.system.note, timeout = 5000, urgency = "critical" })
end

function notify.success(message)
    notify.send({ text = message, icon = ICONS.system.info, timeout = 2000 })
end

function notify.info(message)
    notify.send({ text = message, icon = ICONS.system.info, timeout = 3000 })
end

-- ============================================
-- VOLUME
-- ============================================

local function volume_icon(volume, muted)
    if muted then return ICONS.volume.muted end
    if volume >= 70 then return ICONS.volume.high
    elseif volume >= 30 then return ICONS.volume.medium
    else return ICONS.volume.low end
end

---Show a volume change notification with synchronised progress bar.
-- @param volume number 0-100
-- @param muted  boolean
function notify.volume(volume, muted)
    notify.send({
        text    = muted and "Volume: Muted" or string.format("Volume: %d%%", volume),
        icon    = volume_icon(volume, muted),
        timeout = 2000,
        urgency = "low",
        hints   = {
            "int:value:" .. (muted and 0 or volume),
            "string:x-canonical-private-synchronous:volume_notif",
            "boolean:SWAYNC_BYPASS_DND:true",
        },
    })
end

---Show a microphone mute state notification.
-- @param muted boolean
function notify.mic(muted)
    notify.send({
        text    = muted and "Microphone: Muted" or "Microphone: On",
        icon    = muted and ICONS.volume.mic_muted or ICONS.volume.mic_on,
        timeout = 2000,
    })
end

-- ============================================
-- BRIGHTNESS
-- ============================================

local function brightness_icon(level)
    local bucket = math.min(100, math.ceil(level / 20) * 20)
    return ICONS.brightness[bucket] or ICONS.brightness[100]
end

---Show a screen brightness change notification with synchronised progress bar.
-- @param brightness number 0-100
function notify.brightness(brightness)
    notify.send({
        text    = string.format("Brightness: %d%%", brightness),
        icon    = brightness_icon(brightness),
        timeout = 2000,
        urgency = "low",
        hints   = {
            "int:value:" .. brightness,
            "string:x-canonical-private-synchronous:brightness_notif",
            "boolean:SWAYNC_BYPASS_DND:true",
        },
    })
end

---Show a keyboard backlight change notification.
-- @param brightness number 0-100
function notify.kbd_brightness(brightness)
    notify.send({
        text    = string.format("Keyboard brightness: %d%%", brightness),
        icon    = brightness_icon(brightness),
        timeout = 2000,
    })
end

-- ============================================
-- DISPLAY EXTRAS
-- ============================================

---Show a night-light toggle notification.
-- @param enabled boolean
-- @param temp    number|nil Colour temperature in Kelvin (shown when enabling)
function notify.nightlight(enabled, temp)
    if enabled then
        notify.info(string.format("Night light on @ %dK", temp or 4500))
    else
        notify.info("Night light off")
    end
end

---Show a blur toggle notification.
-- @param normal boolean true = normal blur, false = less blur
function notify.blur(normal)
    notify.info(normal and "Normal blur" or "Less blur")
end

-- ============================================
-- SYSTEM
-- ============================================

function notify.screenshot(message)
    notify.send({ text = message or "Screenshot saved", icon = ICONS.system.screenshot, timeout = 3000 })
end

function notify.lock()
    notify.send({ text = "Screen locked", icon = ICONS.system.info, timeout = 2000 })
end

return notify
