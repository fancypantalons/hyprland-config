---
-- Audio Control Functions
-- Provides volume control, media playback, and microphone management
--
-- All functions automatically show notifications and use baked-in increments
--
-- @module user-functions.audio
-- @author Brett
-- @license MIT

local audio = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- ============================================
-- CONFIGURATION
-- ============================================

local ICON_DIR = os.getenv("HOME") .. "/.config/swaync/icons"

local ICONS = {
    volume = {
        high = ICON_DIR .. "/volume-high.png",
        mid = ICON_DIR .. "/volume-mid.png",
        low = ICON_DIR .. "/volume-low.png",
        mute = ICON_DIR .. "/volume-mute.png"
    },
    mic = {
        on = ICON_DIR .. "/microphone.png",
        mute = ICON_DIR .. "/microphone-mute.png"
    },
    music = ICON_DIR .. "/music.png"
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Get the current volume level using pamixer
-- @return number|nil The current volume level (0-100), or nil on error
-- @return string|nil Error message if command failed
local function get_volume()
    local result = helpers.exec("pamixer --get-volume")
    return tonumber(result.stdout:match("%d+"))
end

---Check if the volume is currently muted
-- @return boolean|nil True if muted, false if not, nil on error
local function is_muted()
    local result = helpers.exec("pamixer --get-mute")
    return result.stdout:match("true") ~= nil
end

---Check if the microphone is currently muted
-- @return boolean|nil True if muted, false if not, nil on error
local function is_mic_muted()
    local result = helpers.exec("pamixer --default-source --get-mute")
    return result.stdout:match("true") ~= nil
end

---Get the appropriate volume icon based on volume level and mute state
-- @param volume number The current volume level
-- @param muted boolean Whether the volume is muted
-- @return string The path to the appropriate icon
local function get_volume_icon(volume, muted)
    if muted then
        return ICONS.volume.mute
    end

    if volume <= 30 then
        return ICONS.volume.low
    elseif volume <= 60 then
        return ICONS.volume.mid
    else
        return ICONS.volume.high
    end
end

---Play a sound effect for volume changes
-- Uses pw-play or paplay with freedesktop theme sounds
local function play_volume_sound()
    local sound_file = nil
    local system_dirs = {
        "/run/current-system/sw/share/sounds/freedesktop/stereo",
        "/usr/share/sounds/freedesktop/stereo",
        os.getenv("HOME") .. "/.local/share/sounds/freedesktop/stereo"
    }

    for _, dir in ipairs(system_dirs) do
        local cmd = string.format("ls %s/audio-volume-change.* 2>/dev/null | head -1", dir)
        local result = helpers.exec(cmd)

        if result.success and result.stdout and result.stdout ~= "" then
            sound_file = result.stdout:gsub("%s+$", "")

            break
        end
    end

    if sound_file then
        hl.exec_cmd(string.format("pw-play '%s' 2>/dev/null || paplay '%s' 2>/dev/null", sound_file, sound_file))
    end
end

---Send a volume notification
-- @param volume number The current volume level
-- @param muted boolean Whether the volume is muted
local function notify_volume(volume, muted)
    local icon = get_volume_icon(volume, muted)
    local notify = require("utils.notify")

    if muted then
        notify.send({
            text = "Volume: Muted",
            icon = icon,
            timeout = 2000
        })
    else
        notify.send({
            text = string.format("Volume: %d%%", volume),
            icon = icon,
            timeout = 2000
        })
    end
end

---Send a microphone notification
-- @param muted boolean Whether the microphone is muted
local function notify_mic(muted)
    local icon = muted and ICONS.mic.mute or ICONS.mic.on
    local text = muted and "Microphone: Muted" or "Microphone: On"

    notify.send({
        text = text,
        icon = icon,
        timeout = 2000
    })
end

---Send a media notification
-- @param title string The notification title
-- @param message string The notification message
local function notify_media(title, message)
    notify.send({
        text = message,
        icon = ICONS.music,
        timeout = 2000
    })
end

-- ============================================
-- VOLUME CONTROL
-- ============================================

---Increase the master volume by 5%
-- If currently muted, unmutes first
-- Automatically shows a notification with the new volume level and plays a sound
-- @function volume_up
function audio.volume_up()
    local success, err = pcall(function()
        local muted = is_muted()

        if muted == nil then
            local notify = require("utils.notify")
            notify.error("Failed to check mute state")

            return
        end

        if muted then
            local result = helpers.exec("pamixer -u")

            if not result.success then
                local notify = require("utils.notify")
                notify.error("Failed to unmute", result.stderr)

                return
            end
        end

        local result = helpers.exec("pamixer -i 5 --allow-boost --set-limit 150")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to increase volume", result.stderr)

            return
        end

        local volume = get_volume()

        if volume then
            notify_volume(volume, false)
            play_volume_sound()
        end
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Volume up failed", tostring(err))
    end
end

---Decrease the master volume by 5%
-- If currently muted, unmutes first
-- Automatically shows a notification with the new volume level and plays a sound
-- @function volume_down
function audio.volume_down()
    local success, err = pcall(function()
        local muted = is_muted()

        if muted == nil then
            local notify = require("utils.notify")
            notify.error("Failed to check mute state")

            return
        end

        if muted then
            local result = helpers.exec("pamixer -u")

            if not result.success then
                local notify = require("utils.notify")
                notify.error("Failed to unmute", result.stderr)

                return
            end
        end

        local result = helpers.exec("pamixer -d 5")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to decrease volume", result.stderr)

            return
        end

        local volume = get_volume()

        if volume then
            notify_volume(volume, false)
            play_volume_sound()
        end
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Volume down failed", tostring(err))
    end
end

---Toggle the master volume mute state
-- Shows a notification indicating the new mute state
-- @function volume_toggle
function audio.volume_toggle()
    local success, err = pcall(function()
        local muted = is_muted()

        if muted == nil then
            local notify = require("utils.notify")
            notify.error("Failed to check mute state")

            return
        end

        local result

        if muted then
            result = helpers.exec("pamixer -u")
        else
            result = helpers.exec("pamixer -m")
        end

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to toggle mute", result.stderr)

            return
        end

        local new_muted = not muted
        local volume = get_volume() or 0

        notify_volume(volume, new_muted)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Volume toggle failed", tostring(err))
    end
end

---Toggle the microphone mute state
-- Shows a notification indicating the new microphone state
-- @function mic_toggle
function audio.mic_toggle()
    local success, err = pcall(function()
        local muted = is_mic_muted()

        if muted == nil then
            local notify = require("utils.notify")
            notify.error("Failed to check mic state")

            return
        end

        local result

        if muted then
            result = helpers.exec("pamixer --default-source -u")
        else
            result = helpers.exec("pamixer --default-source -m")
        end

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to toggle mic", result.stderr)

            return
        end

        notify_mic(not muted)
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Mic toggle failed", tostring(err))
    end
end

-- ============================================
-- MEDIA PLAYBACK
-- ============================================

---Play or pause the current media
-- Shows a notification with the current playback state and track info
-- @function media_play
function audio.media_play()
    local success, err = pcall(function()
        local result = helpers.exec("playerctl play-pause")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to toggle playback", result.stderr)

            return
        end

        helpers.sleep(0.1)

        local status_result = helpers.exec("playerctl status")

        if status_result.success then
            local status = status_result.stdout:gsub("%s+$", "")

            if status == "Playing" then
                local title_result = helpers.exec("playerctl metadata title")
                local artist_result = helpers.exec("playerctl metadata artist")
                local title = title_result.success and title_result.stdout:gsub("%s+$", "") or "Unknown"
                local artist = artist_result.success and artist_result.stdout:gsub("%s+$", "") or "Unknown"

                notify_media("Now Playing", string.format("%s by %s", title, artist))
            elseif status == "Paused" then
                notify_media("Playback", "Paused")
            end
        end
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Media play failed", tostring(err))
    end
end

---Skip to the next track
-- Shows a notification with the new track information
-- @function media_next
function audio.media_next()
    local success, err = pcall(function()
        local result = helpers.exec("playerctl next")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to skip track", result.stderr)

            return
        end

        helpers.sleep(0.1)

        local title_result = helpers.exec("playerctl metadata title")
        local artist_result = helpers.exec("playerctl metadata artist")
        local title = title_result.success and title_result.stdout:gsub("%s+$", "") or "Unknown"
        local artist = artist_result.success and artist_result.stdout:gsub("%s+$", "") or "Unknown"

        notify_media("Now Playing", string.format("%s by %s", title, artist))
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Media next failed", tostring(err))
    end
end

---Go back to the previous track
-- Shows a notification with the track information
-- @function media_prev
function audio.media_prev()
    local success, err = pcall(function()
        local result = helpers.exec("playerctl previous")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to go to previous track", result.stderr)

            return
        end

        helpers.sleep(0.1)

        local title_result = helpers.exec("playerctl metadata title")
        local artist_result = helpers.exec("playerctl metadata artist")
        local title = title_result.success and title_result.stdout:gsub("%s+$", "") or "Unknown"
        local artist = artist_result.success and artist_result.stdout:gsub("%s+$", "") or "Unknown"

        notify_media("Now Playing", string.format("%s by %s", title, artist))
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Media previous failed", tostring(err))
    end
end

---Stop media playback
-- Shows a notification indicating playback has stopped
-- @function media_stop
function audio.media_stop()
    local success, err = pcall(function()
        local result = helpers.exec("playerctl stop")

        if not result.success then
            local notify = require("utils.notify")
            notify.error("Failed to stop playback", result.stderr)

            return
        end

        notify_media("Playback", "Stopped")
    end)

    if not success then
        local notify = require("utils.notify")
        notify.error("Media stop failed", tostring(err))
    end
end

return audio
