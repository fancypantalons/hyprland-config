-- Wallpaper control: selection, effects, randomisation, wallust colour extraction,
-- auto-rotation daemon, and optional SDDM background sync.

local wallpaper = {}
local helpers   = require("utils.helpers")
local notify    = require("utils.notify")
local proc      = require("utils.proc")
local refresh   = require("utils.refresh")

local HOME = os.getenv("HOME")

local PATHS = {
    wallpapers        = HOME .. "/Pictures/wallpapers",
    swww_cache        = HOME .. "/.cache/swww",
    rofi_current      = HOME .. "/.config/rofi/.current_wallpaper",
    wallpaper_current = HOME .. "/.config/hypr/wallpaper_effects/.wallpaper_current",
    wallpaper_modified= HOME .. "/.config/hypr/wallpaper_effects/.wallpaper_modified",
    gif_cache         = HOME .. "/.cache/gif_preview",
    video_cache       = HOME .. "/.cache/video_preview",
    rofi_theme        = HOME .. "/.config/rofi/config-wallpaper.rasi",
    rofi_effect_theme = HOME .. "/.config/rofi/config-wallpaper-effect.rasi",
    scripts_dir       = HOME .. "/.config/hypr/scripts",
    sddm_themes = {
        "/usr/share/sddm/themes",
        "/run/current-system/sw/share/sddm/themes",
    },
}

local SWWW = { fps = 60, type = "any", duration = 2, bezier = ".43,1.19,1,.4" }
local AUTO_CHANGE_INTERVAL = 1800

local IMAGE_EXTS = { "jpg","jpeg","png","gif","bmp","tiff","webp","pnm","tga","farbfeld" }
local VIDEO_EXTS = { "mp4","mkv","mov","webm" }

-- ============================================
-- INTERNAL HELPERS
-- ============================================

local function focused_monitor()
    local m = hl.get_active_monitor()
    return m and m.name or nil
end

local function is_video(path)
    local lower = path:lower()
    for _, ext in ipairs(VIDEO_EXTS) do
        if lower:match("%." .. ext .. "$") then return true end
    end
    return false
end

local function is_gif(path) return path:lower():match("%.gif$") ~= nil end

local function kill_wallpaper_daemons(keep_swww)
    if not keep_swww then hl.exec_cmd("swww kill 2>/dev/null || true") end
    hl.exec_cmd("pkill mpvpaper 2>/dev/null || true")
    hl.exec_cmd("pkill swaybg   2>/dev/null || true")
    hl.exec_cmd("pkill hyprpaper 2>/dev/null || true")
end

local function find_ext_pattern()
    local parts = {}
    for _, e in ipairs(IMAGE_EXTS) do table.insert(parts, "-iname '*." .. e .. "'") end
    for _, e in ipairs(VIDEO_EXTS) do table.insert(parts, "-iname '*." .. e .. "'") end
    return table.concat(parts, " -o ")
end

local function get_wallpaper_list()
    local r = helpers.exec(string.format(
        "find -L %s -type f \\( %s \\) -print 2>/dev/null | sort",
        helpers.shquote(PATHS.wallpapers), find_ext_pattern()
    ))
    if not r.success then return {} end
    local list = {}
    for line in r.stdout:gmatch("[^\r\n]+") do table.insert(list, line) end
    return list
end

local function gen_thumbnail(src, cache_dir, cmd_fmt)
    local name  = src:match("([^/]+)$")
    local cache = cache_dir .. "/" .. name .. ".png"
    helpers.mkdir_p(cache_dir)
    if not helpers.path_exists(cache) then helpers.exec(string.format(cmd_fmt, src, cache, src, cache)) end
    return cache
end

local function thumbnail(path)
    if is_gif(path) then
        return gen_thumbnail(path, PATHS.gif_cache,
            "magick '%s[0]' -resize 1920x1080 '%s' 2>/dev/null || convert '%s[0]' -resize 1920x1080 '%s' 2>/dev/null")
    elseif is_video(path) then
        return gen_thumbnail(path, PATHS.video_cache,
            "ffmpeg -v error -y -i '%s' -ss 00:00:01.000 -vframes 1 '%s' 2>/dev/null; true; true; true")
    end
    return path
end

local function sddm_theme_dir()
    for _, dir in ipairs(PATHS.sddm_themes) do
        if helpers.dir_exists(dir) then
            local t = dir .. "/simple_sddm_2"
            if helpers.dir_exists(t) and helpers.path_exists(t .. "/Backgrounds") then
                return t
            end
        end
    end
    return nil
end

local function offer_sddm(is_effect)
    local theme_dir = sddm_theme_dir()
    if not theme_dir then return end

    proc.kill("yad")
    helpers.exec_async(
        "yad --info --text='Set current wallpaper as SDDM background?' "
        .. "--title='SDDM Background' --timeout=5 --timeout-indicator=right "
        .. "--button='yes:0' --button='no:1' 2>/dev/null",
        function(exit_code, _)
            if exit_code ~= 0 then return end
            if not proc.have("kitty") then
                notify.error("Missing kitty", "Install kitty to set SDDM background"); return
            end
            local wp = is_effect and PATHS.wallpaper_modified or PATHS.wallpaper_current
            local script = PATHS.scripts_dir .. "/sddm-wallpaper.sh"
            local rofi_wallust = HOME .. "/.config/rofi/wallust/colors-rofi.rasi"
            hl.exec_cmd(string.format("kitty -e bash %s %s %s %s &",
                helpers.shquote(script),
                helpers.shquote(wp),
                helpers.shquote(theme_dir),
                helpers.shquote(rofi_wallust)))
        end
    )
end

local function swww_apply(image_path, monitor, on_done)
    local cmd = string.format(
        "swww img -o %s %s --transition-fps %d --transition-type %s --transition-duration %d --transition-bezier %s",
        monitor, helpers.shquote(image_path),
        SWWW.fps, SWWW.type, SWWW.duration, SWWW.bezier
    )
    helpers.exec_async(cmd, function(exit_code, _)
        pcall(function()
            if exit_code ~= 0 then notify.error("Failed to apply wallpaper"); return end
            if on_done then on_done() end
        end)
    end)
end

local function apply_image(image_path, monitor, on_done)
    local target = monitor or focused_monitor()
    if not target then notify.error("Could not detect monitor"); return end
    kill_wallpaper_daemons(true)

    if proc.running("swww-daemon") then
        swww_apply(image_path, target, on_done)
    else
        hl.exec_cmd("swww-daemon --format xrgb &")
        helpers.delay(0.5, function() swww_apply(image_path, target, on_done) end)
    end
end

local function apply_video(video_path)
    if not proc.have("mpvpaper") then
        notify.error("mpvpaper not found", "Install mpvpaper for video wallpapers"); return
    end
    kill_wallpaper_daemons(false)
    hl.exec_cmd(string.format("mpvpaper '*' -o 'load-scripts=no no-audio --loop' %s &",
        helpers.shquote(video_path)))
    notify.success("Video wallpaper applied")
end

local function get_rofi_icon_size()
    local m = hl.get_active_monitor()
    if not m then return "element-icon{size:20%;}" end
    local sz = math.max(15, math.min(25, math.floor((m.height * 3) / (m.scale * 150))))
    return string.format("element-icon{size:%d%%;}", sz)
end

local function current_wallpaper_from_swww()
    local mon = focused_monitor()
    if not mon then return nil end
    local r = helpers.exec(string.format("swww query | grep %s | awk '{print $9}'",
        helpers.shquote(mon)))
    return r.success and helpers.trim(r.stdout) ~= "" and helpers.trim(r.stdout) or nil
end

-- ============================================
-- PUBLIC
-- ============================================

---Extract colours from the current wallpaper and regenerate wallust templates.
-- @param image_path string|nil  Explicit path; falls back to swww cache.
function wallpaper.apply_wallust(image_path)
    helpers.safe_call("Wallust application failed", function()
        local path = image_path or current_wallpaper_from_swww()
        if not path or path == "" or not helpers.file_exists(path) then return end

        hl.exec_cmd(string.format("ln -sf %s %s", helpers.shquote(path), helpers.shquote(PATHS.rofi_current)))
        helpers.mkdir_p(PATHS.wallpaper_current:match("(.+)/[^/]+"))
        hl.exec_cmd(string.format("cp -f %s %s", helpers.shquote(path), helpers.shquote(PATHS.wallpaper_current)))
        hl.exec_cmd("wallust run -s " .. helpers.shquote(path))
    end)
end

---Show a rofi picker for selecting a wallpaper from ~/Pictures/wallpapers.
function wallpaper.select()
    if not proc.have("bc") then notify.error("bc missing", "Install bc first"); return end

    helpers.safe_call("Wallpaper select failed", function()
        proc.kill("rofi")
        local mon = focused_monitor()
        if not mon then notify.error("Could not detect monitor"); return end

        local all = get_wallpaper_list()
        if #all == 0 then notify.error("No wallpapers found", PATHS.wallpapers); return end

        -- Build rofi icon-menu items.
        local items = { { label = ". random", icon = all[math.random(1, #all)] } }
        for _, p in ipairs(all) do
            local name = p:match("([^/]+)$"):gsub("%..-$", "")
            table.insert(items, { label = name, icon = thumbnail(p) })
        end

        -- We need the original path by label for the callback.
        local label_to_path = {}
        for i, p in ipairs(all) do
            label_to_path[items[i + 1].label] = p
        end

        local icon_override = get_rofi_icon_size()

        -- Build and run rofi manually so we can pass -theme-str.
        local tmpfile = "/tmp/hypr-wallpaper-menu-" .. os.time() .. ".txt"
        local lines = {}
        for _, item in ipairs(items) do
            table.insert(lines, item.label .. "\0icon\x1f" .. item.icon)
        end
        helpers.write_file(tmpfile, table.concat(lines, "\n"))

        local cmd = string.format(
            "cat %s | rofi -i -show -dmenu -config %s -theme-str %s",
            helpers.shquote(tmpfile),
            helpers.shquote(PATHS.rofi_theme),
            helpers.shquote(icon_override)
        )

        helpers.exec_async(cmd, function(_, raw)
            os.remove(tmpfile)
            pcall(function()
                local choice = helpers.trim(raw or "")
                if choice == "" then return end

                if choice == ". random" then wallpaper.random(); return end

                local selected = label_to_path[choice]
                if not selected then
                    -- Fallback: find by name prefix.
                    local fr = helpers.exec(string.format("find %s -iname %s -print -quit",
                        helpers.shquote(PATHS.wallpapers), helpers.shquote(choice .. "*")))
                    selected = helpers.trim(fr.stdout)
                end
                if not selected or selected == "" then notify.error("Wallpaper not found", choice); return end

                if is_video(selected) then
                    notify.info("Video wallpaper active this session only — update autostart.lua to persist")
                    apply_video(selected)
                else
                    apply_image(selected, mon, function()
                        wallpaper.apply_wallust(selected)
                        refresh.refresh_ui(function() offer_sddm(false) end)
                    end)
                end
            end)
        end)
    end)
end

---Apply a random image wallpaper from the collection.
function wallpaper.random()
    helpers.safe_call("Random wallpaper failed", function()
        local all = get_wallpaper_list()
        local images = {}
        for _, w in ipairs(all) do if not is_video(w) then table.insert(images, w) end end
        if #images == 0 then notify.error("No image wallpapers found"); return end

        local selected = images[math.random(1, #images)]
        local mon      = focused_monitor()
        if not mon then notify.error("Could not detect monitor"); return end

        kill_wallpaper_daemons(true)

        local cmd = string.format(
            "swww img -o %s %s --transition-fps 30 --transition-type random --transition-duration 1 --transition-bezier .43,1.19,1,.4",
            mon, helpers.shquote(selected)
        )

        local function apply_and_refresh()
            wallpaper.apply_wallust(selected)
            refresh.refresh_ui(function() notify.success("Random wallpaper applied") end)
        end

        if proc.running("swww-daemon") then
            helpers.exec_async(cmd, function(_, _) pcall(apply_and_refresh) end)
        else
            hl.exec_cmd("swww-daemon --format xrgb &")
            helpers.delay(0.5, function()
                helpers.exec_async(cmd, function(_, _) pcall(apply_and_refresh) end)
            end)
        end
    end)
end

---Show a rofi effect picker; applies ImageMagick effects to the current wallpaper.
function wallpaper.effects()
    if not proc.have("magick") and not proc.have("convert") then
        notify.error("ImageMagick not found", "Install imagemagick for effects"); return
    end

    local EFFECTS = {
        ["No Effects"]   = "none",
        ["Black & White"]= "colorspace gray -sigmoidal-contrast 10,40%",
        ["Blurred"]      = "-blur 0x10",
        ["Charcoal"]     = "-charcoal 0x5",
        ["Edge Detect"]  = "-edge 1",
        ["Emboss"]       = "-emboss 0x5",
        ["Frame Raised"] = "+raise 150",
        ["Frame Sunk"]   = "-raise 150",
        ["Negate"]       = "-negate",
        ["Oil Paint"]    = "-paint 4",
        ["Posterize"]    = "-posterize 4",
        ["Polaroid"]     = "-polaroid 0",
        ["Sepia Tone"]   = "-sepia-tone 65%",
        ["Solarize"]     = "-solarize 80%",
        ["Sharpen"]      = "-sharpen 0x5",
        ["Vignette"]     = "-vignette 0x3",
        ["Vignette-black"]= "-background black -vignette 0x3",
        ["Zoomed"]       = "-gravity Center -extent 1:1",
    }

    helpers.safe_call("Wallpaper effects failed", function()
        proc.kill("rofi")

        local names = {}
        for n, _ in pairs(EFFECTS) do table.insert(names, n) end
        table.sort(names)

        local menu_mod = require("utils.menu")
        menu_mod.pick({
            theme = PATHS.rofi_effect_theme,
            items = names,
        }, function(choice, _)
            if not choice then return end
            local mon = focused_monitor()

            if choice == "No Effects" then
                hl.exec_cmd(string.format("cp -f %s %s",
                    helpers.shquote(PATHS.wallpaper_current), helpers.shquote(PATHS.wallpaper_modified)))
                if mon then
                    hl.exec_cmd(string.format(
                        "swww img -o %s %s --transition-fps 60 --transition-type wipe --transition-duration 2 --transition-bezier .43,1.19,1,.4",
                        mon, helpers.shquote(PATHS.wallpaper_current)))
                end
                wallpaper.apply_wallust(PATHS.wallpaper_current)
                helpers.delay(2, function() refresh.refresh_ui(); notify.info("No effects applied") end)
                return
            end

            local params = EFFECTS[choice]
            if not params then return end

            notify.info("Applying: " .. choice)

            local magick_cmd = string.format(
                "magick %s %s %s 2>/dev/null || convert %s %s %s 2>/dev/null",
                helpers.shquote(PATHS.wallpaper_current), params, helpers.shquote(PATHS.wallpaper_modified),
                helpers.shquote(PATHS.wallpaper_current), params, helpers.shquote(PATHS.wallpaper_modified)
            )
            hl.exec_cmd(magick_cmd)
            proc.signal("swaybg",   "SIGUSR1")
            proc.signal("mpvpaper", "SIGUSR1")

            helpers.delay(1, function()
                if mon then
                    hl.exec_cmd(string.format(
                        "swww img -o %s %s --transition-fps 60 --transition-type wipe --transition-duration 2 --transition-bezier .43,1.19,1,.4",
                        mon, helpers.shquote(PATHS.wallpaper_modified)))
                end
                helpers.delay(2, function()
                    hl.exec_cmd("wallust run " .. helpers.shquote(PATHS.wallpaper_modified) .. " -s")
                    helpers.delay(1, function()
                        refresh.refresh_ui()
                        notify.success(choice .. " effects applied")
                        offer_sddm(true)
                    end)
                end)
            end)
        end)
    end)
end

---Start the auto-rotation daemon (changes wallpaper every AUTO_CHANGE_INTERVAL seconds).
function wallpaper.auto_change()
    helpers.safe_call("Auto-change failed", function()
        local all = get_wallpaper_list()
        local images = {}
        for _, w in ipairs(all) do if not is_video(w) then table.insert(images, w) end end
        if #images == 0 then notify.error("No image wallpapers for auto-change"); return end

        notify.info("Starting wallpaper auto-change daemon")

        local ext_glob = "-name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp'"
        local script = string.format([[
#!/bin/bash
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple
INTERVAL=%d
USERSCRIPTS="%s"
ROFI_LINK="%s"
WALLPAPER_CURRENT="%s"

apply_wallust() {
    local img="$1"
    ln -sf "$img" "$ROFI_LINK" || true
    mkdir -p "$(dirname "$WALLPAPER_CURRENT")"
    cp -f "$img" "$WALLPAPER_CURRENT" || true
    wallust run -s "$img" || true
}

refresh_no_waybar() {
    pkill rofi 2>/dev/null || true
    ags -q 2>/dev/null || true; sleep 0.1; ags &
    sleep 0.2; swaync-client --reload-config
    sleep 1
    [ -f "${USERSCRIPTS}/RainbowBorders.sh" ] && "${USERSCRIPTS}/RainbowBorders.sh" &
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
            PATHS.scripts_dir,
            PATHS.rofi_current,
            PATHS.wallpaper_current,
            PATHS.wallpapers,
            ext_glob
        )

        local tmp = "/tmp/hyprland_wallpaper_daemon.sh"
        helpers.write_file(tmp, script)
        proc.kill_pat("hyprland_wallpaper_daemon")
        hl.exec_cmd("bash " .. helpers.shquote(tmp) .. " &")
        notify.success("Auto-change daemon started (" .. AUTO_CHANGE_INTERVAL .. "s interval)")
    end)
end

return wallpaper
