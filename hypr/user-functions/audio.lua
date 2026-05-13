-- Audio control: volume, microphone, and media playback.

local audio   = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local proc    = require("utils.proc")

-- ============================================
-- INTERNAL HELPERS
-- ============================================

local function get_volume()
    return tonumber(helpers.exec("pamixer --get-volume").stdout:match("%d+"))
end

local function is_muted()
    return helpers.exec("pamixer --get-mute").stdout:match("true") ~= nil
end

local function is_mic_muted()
    return helpers.exec("pamixer --default-source --get-mute").stdout:match("true") ~= nil
end

local SOUND_DIRS = {
    "/run/current-system/sw/share/sounds/freedesktop/stereo",
    "/usr/share/sounds/freedesktop/stereo",
    os.getenv("HOME") .. "/.local/share/sounds/freedesktop/stereo",
}

local function play_volume_sound()
    for _, dir in ipairs(SOUND_DIRS) do
        local r = helpers.exec(string.format("ls %s/audio-volume-change.* 2>/dev/null | head -1", dir))
        if r.success and helpers.trim(r.stdout) ~= "" then
            local f = helpers.trim(r.stdout)
            hl.exec_cmd(string.format("pw-play %s 2>/dev/null || paplay %s 2>/dev/null",
                helpers.shquote(f), helpers.shquote(f)))
            return
        end
    end
end

-- Unmute if muted, then run the pamixer adjustment command.
local function volume_adjust(pamixer_args)
    if is_muted() then helpers.exec("pamixer -u") end
    helpers.exec("pamixer " .. pamixer_args)
    local vol = get_volume()
    if vol then notify.volume(vol, false); play_volume_sound() end
end

local function notify_media(message)
    notify.send({ text = message, icon = require("utils.icons").media.music, timeout = 2000 })
end

-- Run a playerctl action, then asynchronously read status + metadata and notify.
local function exec_media_action(action, check_status)
    local cmd = string.format(
        "playerctl %s; sleep 0.1; echo \"%s$(playerctl metadata title)\n$(playerctl metadata artist)\"",
        action,
        check_status and "$(playerctl status)\n" or ""
    )

    helpers.exec_async(cmd, function(_, out)
        pcall(function()
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do
                table.insert(lines, helpers.trim(line))
            end

            if check_status then
                local status = lines[1] or ""
                if status == "Playing" then
                    notify_media(string.format("%s by %s", lines[2] or "Unknown", lines[3] or "Unknown"))
                elseif status == "Paused" then
                    notify_media("Paused")
                end
            else
                notify_media(string.format("%s by %s", lines[1] or "Unknown", lines[2] or "Unknown"))
            end
        end)
    end)
end

-- ============================================
-- VOLUME
-- ============================================

function audio.volume_up()
    helpers.safe_call("Volume up failed", function()
        volume_adjust("-i 5 --allow-boost --set-limit 150")
    end)
end

function audio.volume_down()
    helpers.safe_call("Volume down failed", function()
        volume_adjust("-d 5")
    end)
end

function audio.volume_toggle()
    helpers.safe_call("Volume toggle failed", function()
        local muted = is_muted()
        helpers.exec(muted and "pamixer -u" or "pamixer -m")
        notify.volume(get_volume() or 0, not muted)
    end)
end

-- ============================================
-- MICROPHONE
-- ============================================

function audio.mic_toggle()
    helpers.safe_call("Mic toggle failed", function()
        local muted = is_mic_muted()
        helpers.exec(muted and "pamixer --default-source -u" or "pamixer --default-source -m")
        notify.mic(not muted)
    end)
end

-- ============================================
-- MEDIA PLAYBACK
-- ============================================

function audio.media_play()  exec_media_action("play-pause", true)  end
function audio.media_next()  exec_media_action("next",       false) end
function audio.media_prev()  exec_media_action("previous",   false) end

function audio.media_stop()
    helpers.exec_async("playerctl stop", function(_, _)
        notify_media("Stopped")
    end)
end

return audio
