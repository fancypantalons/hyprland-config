---
-- Wallpaper Control Functions
-- Provides wallpaper selection, effects, randomization, and auto-rotation
--
-- All functions support both image and video wallpapers
-- Uses swww for images and mpvpaper for videos
--
-- @module user-functions.wallpaper
-- @author Brett
-- @license MIT

local wallpaper = {}
local helpers = require("utils.helpers")
local notify = require("utils.notify")

-- Load refresh module for internal refresh functions
local refresh = require("utils.refresh")

-- ============================================
-- CONFIGURATION
-- ============================================

local HOME = os.getenv("HOME")

local PATHS = {
    wallpapers = HOME .. "/Pictures/wallpapers",
    swww_cache = HOME .. "/.cache/swww",
    rofi_current = HOME .. "/.config/rofi/.current_wallpaper",
    wallpaper_current = HOME .. "/.config/hypr/wallpaper_effects/.wallpaper_current",
    wallpaper_modified = HOME .. "/.config/hypr/wallpaper_effects/.wallpaper_modified",
    gif_cache = HOME .. "/.cache/gif_preview",
    video_cache = HOME .. "/.cache/video_preview",
    startup_config = HOME .. "/.config/hypr/UserConfigs/Startup_Apps.conf",
    scripts_dir = HOME .. "/.config/hypr/scripts",
    rofi_theme = HOME .. "/.config/rofi/config-wallpaper.rasi",
    rofi_effect_theme = HOME .. "/.config/rofi/config-wallpaper-effect.rasi",
    swaync_images = HOME .. "/.config/swaync/images",
    sddm_themes = {
        "/usr/share/sddm/themes",
        "/run/current-system/sw/share/sddm/themes"
    }
}

local SWWW_PARAMS = {
    fps = 60,
    type = "any",
    duration = 2,
    bezier = ".43,1.19,1,.4"
}

local AUTO_CHANGE_INTERVAL = 1800

local IMAGE_EXTENSIONS = {
    "jpg", "jpeg", "png", "gif", "bmp",
    "tiff", "webp", "pnm", "tga", "farbfeld"
}

local VIDEO_EXTENSIONS = {
    "mp4", "mkv", "mov", "webm"
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Get the currently focused monitor name
-- @return string|nil The monitor name, or nil on error
local function get_focused_monitor()
    local m = hl.get_active_monitor()
    return m and m.name or nil
end

---Kill all wallpaper daemon processes
-- Stops swww, mpvpaper, swaybg, and hyprpaper
local function kill_wallpaper_daemons()
    hl.exec_cmd("swww kill 2>/dev/null || true")
    hl.exec_cmd("pkill mpvpaper 2>/dev/null || true")
    hl.exec_cmd("pkill swaybg 2>/dev/null || true")
    hl.exec_cmd("pkill hyprpaper 2>/dev/null || true")
end

---Kill wallpaper daemons except swww
-- For image wallpapers, keep swww running
local function kill_non_swww_daemons()
    hl.exec_cmd("pkill mpvpaper 2>/dev/null || true")
    hl.exec_cmd("pkill swaybg 2>/dev/null || true")
    hl.exec_cmd("pkill hyprpaper 2>/dev/null || true")
end

---Check if a command is available
-- @param cmd string The command to check
-- @return boolean True if the command exists
local function command_exists(cmd)
    local result = helpers.exec("command -v " .. cmd .. " 2>/dev/null")

    return result.success and result.stdout ~= ""
end

---Get list of wallpaper files
-- Searches the wallpapers directory for images and videos
-- @return table Array of wallpaper file paths
local function get_wallpaper_list()
    local wallpapers = {}
    local find_pattern = ""

    for _, ext in ipairs(IMAGE_EXTENSIONS) do
        find_pattern = find_pattern .. " -o -iname '*." .. ext .. "'"
    end

    for _, ext in ipairs(VIDEO_EXTENSIONS) do
        find_pattern = find_pattern .. " -o -iname '*." .. ext .. "'"
    end

    find_pattern = find_pattern:sub(5)

    local cmd = string.format(
        "find -L '%s' -type f \( %s \) -print 2>/dev/null | sort",
        PATHS.wallpapers,
        find_pattern
    )

    local result = helpers.exec(cmd)

    if not result.success then
        return wallpapers
    end

    for line in result.stdout:gmatch("[^\r\n]+") do
        table.insert(wallpapers, line)
    end

    return wallpapers
end

---Check if a file is a video
-- @param filepath string The file path to check
-- @return boolean True if the file is a video
local function is_video(filepath)
    local lower = filepath:lower()

    for _, ext in ipairs(VIDEO_EXTENSIONS) do
        if (lower:match("%." .. ext .. "$") ~= nil) then
            return true
        end
    end

    return false
end

---Check if a file is a GIF
-- @param filepath string The file path to check
-- @return boolean True if the file is a GIF
local function is_gif(filepath)
    return filepath:lower():match("%.gif$") ~= nil
end

---Generate a thumbnail for a GIF
-- @param gif_path string Path to the GIF file
-- @return string Path to the generated thumbnail
local function generate_gif_thumbnail(gif_path)
    local basename = gif_path:match("([^/]+)$")
    local cache_path = PATHS.gif_cache .. "/" .. basename .. ".png"

    hl.exec_cmd("mkdir -p '" .. PATHS.gif_cache .. "'")

    local check_result = helpers.exec("test -f '" .. cache_path .. "'")

    if not check_result.success then
        hl.exec_cmd(string.format(
            "magick '%s[0]' -resize 1920x1080 '%s' 2>/dev/null || convert '%s[0]' -resize 1920x1080 '%s' 2>/dev/null",
            gif_path, cache_path, gif_path, cache_path
        ))
    end

    return cache_path
end

---Generate a thumbnail for a video
-- @param video_path string Path to the video file
-- @return string Path to the generated thumbnail
local function generate_video_thumbnail(video_path)
    local basename = video_path:match("([^/]+)$")
    local cache_path = PATHS.video_cache .. "/" .. basename .. ".png"

    hl.exec_cmd("mkdir -p '" .. PATHS.video_cache .. "'")

    local check_result = helpers.exec("test -f '" .. cache_path .. "'")

    if not check_result.success then
        hl.exec_cmd(string.format(
            "ffmpeg -v error -y -i '%s' -ss 00:00:01.000 -vframes 1 '%s' 2>/dev/null || true",
            video_path, cache_path
        ))
    end

    return cache_path
end

---Build the rofi menu input
-- Creates a list of wallpapers with icons for rofi
-- @return string The menu input for rofi
local function build_rofi_menu()
    local wallpapers = get_wallpaper_list()
    local menu_items = {}

    if (#wallpapers == 0) then
        return ""
    end

    local random_idx = math.random(1, #wallpapers)
    local random_pic = wallpapers[random_idx]

    table.insert(menu_items, string.format(". random\0icon\x1f%s", random_pic))

    for _, pic_path in ipairs(wallpapers) do
        local pic_name = pic_path:match("([^/]+)$")
        local display_name = pic_name:gsub("%..-$", "")
        local icon_path

        if (is_gif(pic_path)) then
            icon_path = generate_gif_thumbnail(pic_path)
        elseif (is_video(pic_path)) then
            icon_path = generate_video_thumbnail(pic_path)
        else
            icon_path = pic_path
        end

        table.insert(menu_items, string.format("%s\0icon\x1f%s", display_name, icon_path))
    end

    return table.concat(menu_items, "\n")
end

---Get rofi icon size based on monitor
-- Calculates appropriate icon size for rofi menu
-- @return string The icon size CSS override
local function get_rofi_icon_override()
    local m = hl.get_active_monitor()

    if not m then
        return "element-icon{size:20%;}"
    end

    local icon_size = (m.height * 3) / (m.scale * 150)

    if icon_size < 15 then
        icon_size = 20
    elseif icon_size > 25 then
        icon_size = 25
    end

    return string.format("element-icon{size:%d%%;}", math.floor(icon_size))
end

---Apply an image wallpaper using swww
-- @param image_path string Path to the image file
-- @param monitor string The monitor to apply to (uses focused if nil)
local function apply_image_wallpaper(image_path, monitor)
    local notify = require("utils.notify")
    local target_monitor = monitor or get_focused_monitor()

    if not target_monitor then
        notify.error("Failed to detect focused monitor")

        return
    end

    kill_non_swww_daemons()

    local daemon_check = helpers.exec("pgrep -x swww-daemon")

    if not daemon_check.success then
        hl.exec_cmd("swww-daemon --format xrgb &")
        helpers.sleep(0.5)
    end

    local swww_cmd = string.format(
        "swww img -o %s '%s' --transition-fps %d --transition-type %s --transition-duration %d --transition-bezier %s",
        target_monitor,
        image_path,
        SWWW_PARAMS.fps,
        SWWW_PARAMS.type,
        SWWW_PARAMS.duration,
        SWWW_PARAMS.bezier
    )

    local result = helpers.exec(swww_cmd)

    if not result.success then
        notify.error("Failed to apply wallpaper", result.stderr)

        return
    end

    wallpaper.apply_wallust(image_path)

    helpers.sleep(2)

    refresh.refresh_ui()

    helpers.sleep(1)

    offer_sddm_wallpaper(false)
end

---Apply a video wallpaper using mpvpaper
-- @param video_path string Path to the video file
local function apply_video_wallpaper(video_path)
    local notify = require("utils.notify")

    if not command_exists("mpvpaper") then
        notify.error("mpvpaper not found", "Install mpvpaper for video wallpapers")

        return
    end

    kill_wallpaper_daemons()

    hl.exec_cmd(string.format(
        "mpvpaper '*' -o 'load-scripts=no no-audio --loop' '%s' &",
        video_path
    ))

    notify.success("Video wallpaper applied")
end

---Offer to set wallpaper as SDDM background
-- Shows a yad dialog if simple_sddm_2 theme exists
-- @param is_effect boolean Whether this is an effect wallpaper
local function offer_sddm_wallpaper(is_effect)
    local notify = require("utils.notify")

    local sddm_dir = nil

    for _, dir in ipairs(PATHS.sddm_themes) do
        local check = helpers.exec("test -d '" .. dir .. "'")

        if (check.success) then
            sddm_dir = dir

            break
        end
    end

    if not sddm_dir then
        return
    end

    local simple_theme = sddm_dir .. "/simple_sddm_2"
    local backgrounds_dir = simple_theme .. "/Backgrounds"
    local check = helpers.exec("test -d '" .. simple_theme .. "' -a -w '" .. backgrounds_dir .. "'")

    if not check.success then
        return
    end

    hl.exec_cmd("pkill yad 2>/dev/null || true")

    local wallpaper_path = is_effect and PATHS.wallpaper_modified or PATHS.wallpaper_current
    local yad_cmd = string.format(
        "yad --info --text='Set current wallpaper as SDDM background?\\n\\nNOTE: This only applies to SIMPLE SDDM v2 Theme' " ..
        "--text-align=left --title='SDDM Background' --timeout=5 --timeout-indicator=right " ..
        "--button='yes:0' --button='no:1' 2>/dev/null"
    )

    local yad_result = helpers.exec(yad_cmd)

    if (yad_result.success and yad_result.exit_code == 0) then
        if not command_exists("kitty") then
            notify.error("Missing kitty", "Install kitty to enable setting SDDM background")

            return
        end

        -- Launch SDDM wallpaper setup
        set_sddm_wallpaper(is_effect and "effects" or "normal")
    end
end

---Set SDDM wallpaper and colors
-- Internal helper to configure SDDM theme with current wallpaper and colors
-- Extracts colors from rofi wallust config and updates SDDM theme.conf
-- Copies wallpaper to SDDM backgrounds directory
-- Handles NixOS detection (skips on NixOS)
-- Launches kitty with sudo commands for privileged operations
-- @param mode string Either "normal" or "effects" to determine which wallpaper to use
local function set_sddm_wallpaper(mode)
    local notify = require("utils.notify")

    local sddm_dir = nil

    for _, dir in ipairs(PATHS.sddm_themes) do
        local check = helpers.exec("test -d '" .. dir .. "'")

        if (check.success) then
            sddm_dir = dir

            break
        end
    end

    if not sddm_dir then
        return
    end

    local simple_theme = sddm_dir .. "/simple_sddm_2"
    local sddm_theme_conf = simple_theme .. "/theme.conf"
    local rofi_wallust = HOME .. "/.config/rofi/wallust/colors-rofi.rasi"
    local wallpaper_current = PATHS.wallpaper_current
    local wallpaper_modified = PATHS.wallpaper_modified

    -- Check if simple_sddm_2 theme exists
    local check = helpers.exec("test -d '" .. simple_theme .. "'")

    if not check.success then
        return
    end

    -- Detect NixOS and skip
    local nixos_check = helpers.exec("hostnamectl 2>/dev/null | grep -q 'Operating System: NixOS'")

    if nixos_check.success then
        notify.info("NixOS detected: skipping SDDM background change")

        return
    end

    -- Extract colors from rofi wallust config
    local color0_result = helpers.exec("grep -oP 'color1:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")
    local color1_result = helpers.exec("grep -oP 'color0:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")
    local color7_result = helpers.exec("grep -oP 'color14:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")
    local color10_result = helpers.exec("grep -oP 'color10:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")
    local color12_result = helpers.exec("grep -oP 'color12:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")
    local color13_result = helpers.exec("grep -oP 'color13:\\s*\\K#[A-Fa-f0-9]+' '" .. rofi_wallust .. "' 2>/dev/null")

    local color0 = color0_result.success and color0_result.stdout:gsub("%s+$", "") or "#ffffff"
    local color1 = color1_result.success and color1_result.stdout:gsub("%s+$", "") or "#000000"
    local color7 = color7_result.success and color7_result.stdout:gsub("%s+$", "") or "#ffffff"
    local color10 = color10_result.success and color10_result.stdout:gsub("%s+$", "") or "#ffffff"
    local color12 = color12_result.success and color12_result.stdout:gsub("%s+$", "") or "#ffffff"
    local color13 = color13_result.success and color13_result.stdout:gsub("%s+$", "") or "#ffffff"

    -- Determine which wallpaper to use
    local wallpaper_path = (mode == "effects") and wallpaper_modified or wallpaper_current

    if not command_exists("kitty") then
        notify.error("Missing kitty", "Install kitty to enable setting SDDM background")

        return
    end

    -- Build the script to run with sudo
    local script_content = string.format([[
echo 'Enter your password to update SDDM wallpapers and colors'

# Update the colors in the SDDM config
sudo sed -i "s/HeaderTextColor=\"#.*\"/HeaderTextColor=\"%s\"/" "%s"
sudo sed -i "s/DateTextColor=\"#.*\"/DateTextColor=\"%s\"/" "%s"
sudo sed -i "s/TimeTextColor=\"#.*\"/TimeTextColor=\"%s\"/" "%s"
sudo sed -i "s/DropdownSelectedBackgroundColor=\"#.*\"/DropdownSelectedBackgroundColor=\"%s\"/" "%s"
sudo sed -i "s/SystemButtonsIconsColor=\"#.*\"/SystemButtonsIconsColor=\"%s\"/" "%s"
sudo sed -i "s/SessionButtonTextColor=\"#.*\"/SessionButtonTextColor=\"%s\"/" "%s"
sudo sed -i "s/VirtualKeyboardButtonTextColor=\"#.*\"/VirtualKeyboardButtonTextColor=\"%s\"/" "%s"
sudo sed -i "s/HighlightBackgroundColor=\"#.*\"/HighlightBackgroundColor=\"%s\"/" "%s"
sudo sed -i "s/LoginFieldTextColor=\"#.*\"/LoginFieldTextColor=\"%s\"/" "%s"
sudo sed -i "s/PasswordFieldTextColor=\"#.*\"/PasswordFieldTextColor=\"%s\"/" "%s"

sudo sed -i "s/DropdownBackgroundColor=\"#.*\"/DropdownBackgroundColor=\"%s\"/" "%s"
sudo sed -i "s/HighlightTextColor=\"#.*\"/HighlightTextColor=\"%s\"/" "%s"

sudo sed -i "s/PlaceholderTextColor=\"#.*\"/PlaceholderTextColor=\"%s\"/" "%s"
sudo sed -i "s/UserIconColor=\"#.*\"/UserIconColor=\"%s\"/" "%s"
sudo sed -i "s/PasswordIconColor=\"#.*\"/PasswordIconColor=\"%s\"/" "%s"

# Copy wallpaper to SDDM theme
sudo cp -f "%s" "%s/Backgrounds/default" || true

# Fallbacks: if theme ships default.jpg or default.png, update those too
if [ -e "%s/Backgrounds/default.jpg" ]; then
    sudo cp -f "%s" "%s/Backgrounds/default.jpg"
fi
if [ -e "%s/Backgrounds/default.png" ]; then
    sudo cp -f "%s" "%s/Backgrounds/default.png"
fi

# Send notification
notify-send -i "%s" "SDDM" "Background SET"
]],
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color13, sddm_theme_conf,
        color12, sddm_theme_conf,
        color12, sddm_theme_conf,
        color12, sddm_theme_conf,
        color1, sddm_theme_conf,
        color10, sddm_theme_conf,
        color7, sddm_theme_conf,
        color7, sddm_theme_conf,
        color7, sddm_theme_conf,
        wallpaper_path, simple_theme,
        simple_theme, wallpaper_path, simple_theme,
        simple_theme, wallpaper_path, simple_theme,
        PATHS.swaync_images .. "/ja.png"
    )

    -- Create temporary script and execute with kitty
    local tmp_script = "/tmp/hyprland_sddm_setup.sh"
    helpers.write_file(tmp_script, script_content)
    hl.exec_cmd("chmod +x '" .. tmp_script .. "'")
    hl.exec_cmd("kitty -e bash '" .. tmp_script .. "' &")
end

---Modify Startup_Apps.conf for video vs image wallpaper
-- Updates the startup config to use appropriate daemon
-- @param selected_file string The selected wallpaper path
local function modify_startup_config(selected_file)
    local notify = require("utils.notify")

    if not selected_file then
        return
    end

    if (is_video(selected_file)) then
        hl.exec_cmd(string.format(
            "sed -i '/^\\s*exec-once\\s*=\\s*swww-daemon\\s*--format\\s*xrgb\\s*$/s/^/#/' '%s'",
            PATHS.startup_config
        ))

        hl.exec_cmd(string.format(
            "sed -i '/^\\s*#\\s*exec-once\\s*=\\s*mpvpaper\\s*.*/s/^#\\s*//;' '%s'",
            PATHS.startup_config
        ))

        local escaped_path = selected_file:gsub(HOME, "$HOME")

        hl.exec_cmd(string.format(
            "sed -i 's|^\\$livewallpaper=.*|\\$livewallpaper=\"%s\"|' '%s'",
            escaped_path,
            PATHS.startup_config
        ))
    else
        hl.exec_cmd(string.format(
            "sed -i '/^\\s*#\\s*exec-once\\s*=\\s*swww-daemon\\s*--format\\s*xrgb\\s*$/s/^#\\s*//;' '%s'",
            PATHS.startup_config
        ))

        hl.exec_cmd(string.format(
            "sed -i '/^\\s*exec-once\\s*=\\s*mpvpaper\\s*.*/s/^/#/' '%s'",
            PATHS.startup_config
        ))
    end
end

---Get the current wallpaper path from swww cache
-- @return string|nil The current wallpaper path
local function get_current_wallpaper_from_cache()
    local monitor = get_focused_monitor()

    if not monitor then
        return nil
    end

    local result = helpers.exec(string.format(
        "swww query | grep %s | awk '{print $9}'",
        monitor
    ))

    if (result.success and result.stdout ~= "") then
        return result.stdout:gsub("%s+$", "")
    end

    return nil
end

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

---Show a rofi menu for selecting a wallpaper
-- Displays wallpapers from ~/Pictures/wallpapers with thumbnails
-- Supports images (jpg, png, gif, webp) and videos (mp4, mkv, mov, webm)
-- Applies wallust colors after setting wallpaper
-- Offers to set as SDDM background (if simple_sddm_2 theme exists)
-- Modifies Startup_Apps.conf for video vs image wallpaper
-- @function select
function wallpaper.select()
    local notify = require("utils.notify")

    if not command_exists("bc") then
        notify.error("bc missing", "Install package bc first")

        return
    end

    local success, err = pcall(function()
        hl.exec_cmd("pkill rofi 2>/dev/null || true")

        local focused_monitor = get_focused_monitor()

        if not focused_monitor then
            notify.error("Could not detect focused monitor")

            return
        end

        local menu_input = build_rofi_menu()

        if (menu_input == "") then
            notify.error("No wallpapers found", "Check " .. PATHS.wallpapers)

            return
        end

        local rofi_override = get_rofi_icon_override()
        local rofi_cmd = string.format(
            "echo '%s' | rofi -i -show -dmenu -config '%s' -theme-str '%s'",
            menu_input:gsub("'", "'\"'\"'"),
            PATHS.rofi_theme,
            rofi_override
        )

        local result = helpers.exec(rofi_cmd)

        if not result.success or result.stdout == "" then
            return
        end

        local choice = result.stdout:gsub("%s+$", "")

        if (choice == "" or choice == ". random") then
            wallpaper.random()

            return
        end

        local selected_name = choice .. "."
        local find_result = helpers.exec(string.format(
            "find '%s' -iname '%s*' -print -quit",
            PATHS.wallpapers,
            choice
        ))

        if not find_result.success or find_result.stdout == "" then
            notify.error("Wallpaper not found", choice)

            return
        end

        local selected_file = find_result.stdout:gsub("%s+$", "")

        modify_startup_config(selected_file)

        if (is_video(selected_file)) then
            apply_video_wallpaper(selected_file)
        else
            apply_image_wallpaper(selected_file, focused_monitor)
        end
    end)

    if not success then
        notify.error("Wallpaper select failed", tostring(err))
    end
end

---Set a random wallpaper from the collection
-- Picks a random image from the wallpaper directory
-- Applies with swww transitions
-- Runs wallust and refreshes the UI
-- @function random
function wallpaper.random()
    local notify = require("utils.notify")

    local success, err = pcall(function()
        local wallpapers = get_wallpaper_list()

        local images_only = {}

        for _, w in ipairs(wallpapers) do
            if not is_video(w) then
                table.insert(images_only, w)
            end
        end

        if (#images_only == 0) then
            notify.error("No image wallpapers found")

            return
        end

        local random_idx = math.random(1, #images_only)
        local selected = images_only[random_idx]
        local monitor = get_focused_monitor()

        if not monitor then
            notify.error("Could not detect focused monitor")

            return
        end

        kill_non_swww_daemons()

        local daemon_check = helpers.exec("pgrep -x swww-daemon")

        if not daemon_check.success then
            hl.exec_cmd("swww-daemon --format xrgb &")
            helpers.sleep(0.5)
        end

        local swww_cmd = string.format(
            "swww img -o %s '%s' --transition-fps 30 --transition-type random --transition-duration 1 --transition-bezier .43,1.19,1,.4",
            monitor,
            selected
        )

        hl.exec_cmd(swww_cmd)

        wallpaper.apply_wallust(selected)

        helpers.sleep(2)

        refresh.refresh_ui()

        notify.success("Random wallpaper applied")
    end)

    if not success then
        notify.error("Random wallpaper failed", tostring(err))
    end
end

---Show a rofi menu for applying ImageMagick effects
-- Offers effects: No Effects, Black & White, Blurred, Charcoal,
-- Edge Detect, Emboss, Frame Raised, Frame Sunk, Negate, Oil Paint,
-- Posterize, Polaroid, Sepia Tone, Solarize, Sharpen, Vignette,
-- Vignette-black, Zoomed
-- Applies effect to current wallpaper and displays with swww
-- Runs wallust on modified image
-- @function effects
function wallpaper.effects()
    local notify = require("utils.notify")

    if not command_exists("magick") and not command_exists("convert") then
        notify.error("ImageMagick not found", "Install imagemagick for wallpaper effects")

        return
    end

    local effects = {
        ["No Effects"] = "none",
        ["Black & White"] = "colorspace gray -sigmoidal-contrast 10,40%",
        ["Blurred"] = "-blur 0x10",
        ["Charcoal"] = "-charcoal 0x5",
        ["Edge Detect"] = "-edge 1",
        ["Emboss"] = "-emboss 0x5",
        ["Frame Raised"] = "+raise 150",
        ["Frame Sunk"] = "-raise 150",
        ["Negate"] = "-negate",
        ["Oil Paint"] = "-paint 4",
        ["Posterize"] = "-posterize 4",
        ["Polaroid"] = "-polaroid 0",
        ["Sepia Tone"] = "-sepia-tone 65%",
        ["Solarize"] = "-solarize 80%",
        ["Sharpen"] = "-sharpen 0x5",
        ["Vignette"] = "-vignette 0x3",
        ["Vignette-black"] = "-background black -vignette 0x3",
        ["Zoomed"] = "-gravity Center -extent 1:1"
    }

    local success, err = pcall(function()
        hl.exec_cmd("pkill rofi 2>/dev/null || true")

        local effect_names = {}

        for name, _ in pairs(effects) do
            table.insert(effect_names, name)
        end

        table.sort(effect_names)

        local menu_input = table.concat(effect_names, "\n")
        local rofi_cmd = string.format(
            "echo '%s' | rofi -dmenu -i -config '%s'",
            menu_input,
            PATHS.rofi_effect_theme
        )

        local result = helpers.exec(rofi_cmd)

        if not result.success or result.stdout == "" then
            return
        end

        local choice = result.stdout:gsub("%s+$", "")

        if (choice == "No Effects") then
            hl.exec_cmd(string.format("cp -f '%s' '%s'", PATHS.wallpaper_current, PATHS.wallpaper_modified))

            local monitor = get_focused_monitor()

            if (monitor) then
                local swww_cmd = string.format(
                    "swww img -o %s '%s' --transition-fps 60 --transition-type wipe --transition-duration 2 --transition-bezier .43,1.19,1,.4",
                    monitor,
                    PATHS.wallpaper_current
                )

                hl.exec_cmd(swww_cmd)
            end

            wallpaper.apply_wallust(PATHS.wallpaper_current)

            helpers.sleep(2)

            refresh.refresh_ui()

            notify.info("No effects applied")

            return
        end

        local effect_params = effects[choice]

        if not effect_params then
            return
        end

        notify.info("Applying: " .. choice .. " effects")

        local magick_cmd = string.format(
            "magick '%s' %s '%s' 2>/dev/null || convert '%s' %s '%s' 2>/dev/null",
            PATHS.wallpaper_current,
            effect_params,
            PATHS.wallpaper_modified,
            PATHS.wallpaper_current,
            effect_params,
            PATHS.wallpaper_modified
        )

        hl.exec_cmd(magick_cmd)

        hl.exec_cmd("killall -SIGUSR1 swaybg 2>/dev/null || true")
        hl.exec_cmd("killall -SIGUSR1 mpvpaper 2>/dev/null || true")

        helpers.sleep(1)

        local monitor = get_focused_monitor()

        if (monitor) then
            local swww_cmd = string.format(
                "swww img -o %s '%s' --transition-fps 60 --transition-type wipe --transition-duration 2 --transition-bezier .43,1.19,1,.4",
                monitor,
                PATHS.wallpaper_modified
            )

            hl.exec_cmd(swww_cmd)
        end

        helpers.sleep(2)

        hl.exec_cmd("wallust run '" .. PATHS.wallpaper_modified .. "' -s")

        helpers.sleep(1)

        refresh.refresh_ui()

        notify.success(choice .. " effects applied")

        offer_sddm_wallpaper(true)
    end)

    if not success then
        notify.error("Wallpaper effects failed", tostring(err))
    end
end

---Start auto-rotation daemon for wallpapers
-- Loops through wallpapers at INTERVAL (default 1800 seconds)
-- Applies each wallpaper with swww transitions
-- Runs wallust for each change
-- This function starts a background process
-- @function auto_change
function wallpaper.auto_change()
    local notify = require("utils.notify")

    local success, err = pcall(function()
        local wallpapers = get_wallpaper_list()

        local images_only = {}

        for _, w in ipairs(wallpapers) do
            if not is_video(w) then
                table.insert(images_only, w)
            end
        end

        if (#images_only == 0) then
            notify.error("No image wallpapers found for auto-change")

            return
        end

        notify.info("Starting wallpaper auto-change daemon")

        local script_content = string.format([[
#!/bin/bash
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple

INTERVAL=%d
USERSCRIPTS="%s"
ROFI_LINK="$HOME/.config/rofi/.current_wallpaper"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

apply_wallust() {
    local img="$1"
    ln -sf "$img" "$ROFI_LINK" || true
    mkdir -p "$(dirname "$WALLPAPER_CURRENT")"
    cp -f "$img" "$WALLPAPER_CURRENT" || true
    wallust run -s "$img" || true
}

# Function to refresh UI without restarting waybar
refresh_no_waybar() {
    pkill rofi 2>/dev/null || true

    ags -q 2>/dev/null || true
    sleep 0.1
    ags &

    sleep 0.2
    swaync-client --reload-config

    sleep 1
    if [ -f "${USERSCRIPTS}/RainbowBorders.sh" ]; then
        "${USERSCRIPTS}/RainbowBorders.sh" &
    fi
}

while true; do
    find '%s' -type f \( %s \) -print 2>/dev/null | while read -r img; do
        echo "$((RANDOM %% 1000)):$img"
    done | sort -n | cut -d':' -f2- | while read -r img; do
        MONITOR=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')
        swww img -o "$MONITOR" "$img"
        apply_wallust "$img"
        refresh_no_waybar
        sleep $INTERVAL
    done
done
]],
            AUTO_CHANGE_INTERVAL,
            HOME .. "/.config/hypr/scripts",
            PATHS.wallpapers,
            "-name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp'"
        )

        local tmp_script = "/tmp/hyprland_wallpaper_daemon.sh"
        helpers.write_file(tmp_script, script_content)
        hl.exec_cmd("chmod +x '" .. tmp_script .. "'")

        hl.exec_cmd("pkill -f 'hyprland_wallpaper_daemon' 2>/dev/null || true")

        hl.exec_cmd("bash '" .. tmp_script .. "' &")

        notify.success("Auto-change daemon started (" .. AUTO_CHANGE_INTERVAL .. "s interval)")
    end)

    if not success then
        notify.error("Auto-change failed", tostring(err))
    end
end

---Extract colors from wallpaper and refresh
-- Determines current wallpaper from swww cache
-- Creates symlinks for rofi and current wallpaper
-- Runs wallust run -s to regenerate color templates
-- @param image_path string|nil Optional explicit image path
-- @function apply_wallust
function wallpaper.apply_wallust(image_path)
    local notify = require("utils.notify")

    local success, err = pcall(function()
        local wallpaper_path = image_path

        if not wallpaper_path then
            wallpaper_path = get_current_wallpaper_from_cache()
        end

        if not wallpaper_path or wallpaper_path == "" then
            local monitor = get_focused_monitor()

            if (monitor) then
                local cache_file = PATHS.swww_cache .. "/" .. monitor
                local cache_check = helpers.exec("test -f '" .. cache_file .. "'")

                if (cache_check.success) then
                    local result = helpers.exec("swww query | grep " .. monitor .. " | awk '{print $9}'")

                    if (result.success) then
                        wallpaper_path = result.stdout:gsub("%s+$", "")
                    end
                end
            end
        end

        if not wallpaper_path or wallpaper_path == "" or not helpers.exec("test -f '" .. wallpaper_path .. "'").success then
            return
        end

        hl.exec_cmd(string.format("ln -sf '%s' '%s'", wallpaper_path, PATHS.rofi_current))

        hl.exec_cmd("mkdir -p '" .. PATHS.wallpaper_current:match("(.+)/[^/]+$") .. "'")

        hl.exec_cmd(string.format("cp -f '%s' '%s'", wallpaper_path, PATHS.wallpaper_current))

        hl.exec_cmd("wallust run -s '" .. wallpaper_path .. "'")
    end)

    if not success then
        notify.error("Wallust application failed", tostring(err))
    end
end

return wallpaper
