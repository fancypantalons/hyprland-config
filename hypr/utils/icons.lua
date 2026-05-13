-- Single source of truth for icon/image paths used across all modules.
-- All domain modules require this instead of each defining their own ICON_DIR.

local HOME     = os.getenv("HOME")
local ICON_DIR = HOME .. "/.config/swaync/icons"
local IMG_DIR  = HOME .. "/.config/swaync/images"

return {
    -- Audio
    volume = {
        high      = ICON_DIR .. "/volume-high.png",
        medium    = ICON_DIR .. "/volume-mid.png",
        low       = ICON_DIR .. "/volume-low.png",
        muted     = ICON_DIR .. "/volume-mute.png",
        mic_on    = ICON_DIR .. "/microphone.png",
        mic_muted = ICON_DIR .. "/microphone-mute.png",
    },
    media = {
        music = ICON_DIR .. "/music.png",
    },
    -- Brightness levels (key = nearest-20 ceiling of %)
    brightness = {
        [20]  = ICON_DIR .. "/brightness-20.png",
        [40]  = ICON_DIR .. "/brightness-40.png",
        [60]  = ICON_DIR .. "/brightness-60.png",
        [80]  = ICON_DIR .. "/brightness-80.png",
        [100] = ICON_DIR .. "/brightness-100.png",
    },
    -- General system imagery
    system = {
        info       = IMG_DIR  .. "/ja.png",
        note       = IMG_DIR  .. "/note.png",
        screenshot = ICON_DIR .. "/picture.png",
        timer      = ICON_DIR .. "/timer.png",
    },
}
