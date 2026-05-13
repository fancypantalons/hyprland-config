-- Rofi-based pickers: music player, calculator, emoji, web search,
-- theme selector, and animation picker.

local rofi    = {}
local helpers = require("utils.helpers")
local notify  = require("utils.notify")
local icons   = require("utils.icons")
local proc    = require("utils.proc")
local menu    = require("utils.menu")
local refresh = require("utils.refresh")

local HOME        = os.getenv("HOME")
local CONFIG_DIR  = HOME .. "/.config"
local HYPR_DIR    = CONFIG_DIR .. "/hypr"
local ROFI_DIR    = CONFIG_DIR .. "/rofi"
local MUSIC_DIR   = HOME .. "/Music"
local SCRIPTS_DIR = HYPR_DIR .. "/scripts"

local ROFI_BEATS_MENU = ROFI_DIR .. "/config-rofi-Beats-menu.rasi"
local ROFI_BEATS      = ROFI_DIR .. "/config-rofi-Beats.rasi"
local ROFI_CALC       = ROFI_DIR .. "/config-calc.rasi"
local ROFI_EMOJI      = ROFI_DIR .. "/config-emoji.rasi"
local ROFI_SEARCH     = ROFI_DIR .. "/config-search.rasi"
local ROFI_ANIMATIONS = ROFI_DIR .. "/config-Animations.rasi"
local ROFI_SELECTOR   = ROFI_DIR .. "/config-rofi-theme.rasi"
local ROFI_CONFIG     = ROFI_DIR .. "/config.rasi"

local ROFI_THEMES_CONFIG = ROFI_DIR .. "/themes"
local ROFI_THEMES_LOCAL  = HOME .. "/.local/share/rofi/themes"
local ANIMATIONS_DIR     = HYPR_DIR .. "/animations"

-- ============================================
-- ONLINE MUSIC STATIONS
-- ============================================

local ONLINE_STATIONS = {
    ["FM - Easy Rock 96.3 📻🎶"]              = "https://radio-stations-philippines.com/easy-rock",
    ["FM - Easy Rock - Baguio 91.9 📻🎶"]     = "https://radio-stations-philippines.com/easy-rock-baguio",
    ["FM - Love Radio 90.7 📻🎶"]             = "https://radio-stations-philippines.com/love",
    ["FM - WRock - CEBU 96.3 📻🎶"]           = "https://onlineradio.ph/126-96-3-wrock.html",
    ["FM - Fresh Philippines 📻🎶"]           = "https://onlineradio.ph/553-fresh-fm.html",
    ["Radio - Lofi Girl 🎧🎶"]               = "https://play.streamafrica.net/lofiradio",
    ["Radio - Chillhop 🎧🎶"]               = "http://stream.zeno.fm/fyn8eh3h5f8uv",
    ["Radio - Ibiza Global 🎧🎶"]            = "https://filtermusic.net/ibiza-global",
    ["Radio - Metal Music 🎧🎶"]             = "https://tunein.com/radio/mETaLmuSicRaDio-s119867/",
    ["YT - Wish 107.5 Pinoy HipHop 📻🎶"]    = "https://youtube.com/playlist?list=PLkrzfEDjeYJnmgMYwCKid4XIFqUKBVWEs&si=vahW_noh4UDJ5d37",
    ["YT - Youtube Top 100 Songs 📹🎶"]      = "https://youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i&si=5jsyfqcoUXBCSLeu",
    ["YT - Wish 107.5 Wishclusives 📹🎶"]    = "https://youtube.com/playlist?list=PLkrzfEDjeYJn5B22H9HOWP3Kxxs-DkPSM&si=d_Ld2OKhGvpH48WO",
    ["YT - Relaxing Piano Music 🎹🎶"]       = "https://youtu.be/6H7hXzjFoVU?si=nZTPREC9lnK1JJUG",
    ["YT - Youtube Remix 📹🎶"]              = "https://youtube.com/playlist?list=PLeqTkIUlrZXlSNn3tcXAa-zbo95j0iN-0",
    ["YT - Korean Drama OST 📹🎶"]           = "https://youtube.com/playlist?list=PLUge_o9AIFp4HuA-A3e3ZqENh63LuRRlQ",
    ["YT - lofi hip hop radio beats 📹🎶"]   = "https://www.youtube.com/live/jfKfPfyJRdk?si=PnJIA9ErQIAw6-qd",
    ["YT - Relaxing Piano Jazz Music 🎹🎶"]  = "https://youtu.be/85UEqRat6E4?si=jXQL1Yp2VP_G6NSn",
}

-- ============================================
-- INTERNAL HELPERS
-- ============================================

local function basename(path) return path:match("([^/]+)$") or path end

-- True if mpv is playing music (excludes mpvpaper).
local function is_music_playing()
    local r = helpers.exec("pgrep -x mpv")
    if not r.success or helpers.trim(r.stdout) == "" then return false end
    local wall = helpers.exec("ps aux | grep -- 'unique-wallpaper-process' | grep -v grep | awk '{print $2}'")
    local wall_pid = wall.success and wall.stdout or ""
    for pid in r.stdout:gmatch("%d+") do
        if not wall_pid:find(pid, 1, true) then return true end
    end
    return false
end

local function stop_music()
    local r = helpers.exec("pgrep -x mpv")
    if not r.success or helpers.trim(r.stdout) == "" then return end
    local wall = helpers.exec("ps aux | grep -- 'unique-wallpaper-process' | grep -v grep | awk '{print $2}'")
    local wall_pid = wall.success and wall.stdout or ""
    for pid in r.stdout:gmatch("%d+") do
        if not wall_pid:find(pid, 1, true) then hl.exec_cmd("kill -9 " .. pid) end
    end
    notify.send({ text = "Music stopped", icon = icons.media.music, timeout = 2000 })
end

local function notify_music(msg)
    notify.send({ text = "Now Playing: " .. msg, icon = icons.media.music, timeout = 3000 })
end

local function get_local_music_files()
    local r = helpers.exec(string.format(
        "find -L %s -type f \\( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp4' \\) 2>/dev/null",
        helpers.shquote(MUSIC_DIR)
    ))
    local files = {}
    if r.success and r.stdout ~= "" then
        for line in r.stdout:gmatch("[^\n]+") do table.insert(files, line) end
    end
    return files
end

local function get_search_engine()
    local defaults = HYPR_DIR .. "/UserConfigs/01-UserDefaults.conf"
    local r = helpers.exec("grep 'Search_Engine' " .. helpers.shquote(defaults) .. " 2>/dev/null | head -1")
    if not r.success or r.stdout == "" then return "https://www.google.com/search?q=" end
    local v = r.stdout:match("=%s*(.+)") or ""
    v = v:gsub('^["\']', ""):gsub('["\']$', ""):gsub("^%s*", ""):gsub("%s*$", "")
    return v ~= "" and v or "https://www.google.com/search?q="
end

-- ============================================
-- PUBLIC
-- ============================================

---Music player: online stations or local files.
function rofi.beats()
    menu.pick({
        theme = ROFI_BEATS_MENU,
        items = {
            "Play from Online Stations",
            "Play from Music directory",
            "Shuffle Play from Music directory",
            "Stop RofiBeats",
        },
    }, function(choice, _)
        if not choice then return end

        if choice == "Stop RofiBeats" then
            if is_music_playing() then stop_music() end
            return
        end

        if choice == "Shuffle Play from Music directory" then
            if is_music_playing() then stop_music() end
            notify.send({ text = "Shuffle play: local music", icon = icons.media.music, timeout = 3000 })
            hl.exec_cmd(string.format("mpv --shuffle --loop-playlist --vid=no %s &", helpers.shquote(MUSIC_DIR)))
            return
        end

        if choice == "Play from Online Stations" then
            local stations = {}
            for name, _ in pairs(ONLINE_STATIONS) do table.insert(stations, name) end
            table.sort(stations)

            menu.pick({ theme = ROFI_BEATS, items = stations }, function(sel, _)
                if not sel then return end
                local url = ONLINE_STATIONS[sel]
                if not url then return end
                if is_music_playing() then stop_music() end
                notify_music(sel)
                hl.exec_cmd(string.format("mpv --shuffle --vid=no %s &", helpers.shquote(url)))
            end)
            return
        end

        if choice == "Play from Music directory" then
            local files = get_local_music_files()
            if #files == 0 then notify.error("No music files found in " .. MUSIC_DIR); return end

            local names, path_map = {}, {}
            for _, fp in ipairs(files) do
                local n = basename(fp)
                table.insert(names, n)
                path_map[n] = fp
            end
            table.sort(names)

            menu.pick({ theme = ROFI_BEATS, items = names }, function(sel, _)
                if not sel then return end
                if is_music_playing() then stop_music() end
                notify_music(sel)
                hl.exec_cmd(string.format("cd %s && mpv --loop-playlist --vid=no %s &",
                    helpers.shquote(MUSIC_DIR), helpers.shquote(sel)))
            end)
        end
    end)
end

---Interactive calculator using qalc. Loops until dismissed.
function rofi.calc()
    proc.kill("rofi")

    local function calc_loop(last_result, last_input)
        local mesg = (last_result ~= "" and last_input ~= "")
            and string.format("%s  =  %s", last_input, last_result)
            or ""

        local parts = { "rofi", "-i", "-dmenu", "-config", helpers.shquote(ROFI_CALC) }
        if mesg ~= "" then table.insert(parts, "-mesg " .. helpers.shquote(mesg)) end

        helpers.exec_async(table.concat(parts, " "), function(exit_code, raw)
            pcall(function()
                if exit_code == 1 or not raw then return end
                local input = helpers.trim(raw)
                if input == "" then return end
                local r = helpers.exec(string.format("qalc -t %s", helpers.shquote(input)))
                local result = r.success and helpers.trim(r.stdout) or ""
                if result ~= "" then
                    hl.exec_cmd(string.format("echo %s | wl-copy", helpers.shquote(result)))
                end
                calc_loop(result, input)
            end)
        end)
    end

    calc_loop("", "")
end

---Emoji picker — copies selected emoji to clipboard.
function rofi.emoji()
    proc.kill("rofi")

    local data_file = (configDir or (os.getenv("HOME") .. "/.config/hypr")) .. "/data/emoji.txt"
    local tmpfile   = "/tmp/rofi-emoji-" .. tostring(os.time()) .. ".txt"

    local data = helpers.read_file(data_file)
    if not data then notify.error("Emoji data file not found", data_file); return end
    helpers.write_file(tmpfile, data)

    local cmd = string.format(
        "cat %s | rofi -i -dmenu -mesg %s -config %s | awk '{print $1}' | head -n1 | tr -d '\\n' | wl-copy",
        tmpfile,
        helpers.shquote("Click or Return to choose — Ctrl+V to paste"),
        helpers.shquote(ROFI_EMOJI)
    )

    helpers.exec_async(cmd, function(_, _)
        os.remove(tmpfile)
        notify.info("Emoji copied to clipboard")
    end)
end

---Google (or configured engine) web search via rofi prompt.
function rofi.search()
    local engine = get_search_engine()
    menu.input({
        theme   = ROFI_SEARCH,
        message = "Search via default browser",
    }, function(query)
        if not query then return end
        hl.exec_cmd(string.format("xdg-open %s &", helpers.shquote(engine .. query)))
    end)
end

---Rofi theme selector with live preview. Enter=preview, Ctrl+S=apply, Esc=cancel.
function rofi.theme_selector()
    proc.kill("rofi")

    if not helpers.path_exists(ROFI_THEMES_CONFIG) and not helpers.path_exists(ROFI_THEMES_LOCAL) then
        notify.error("No Rofi themes directory found"); return
    end
    if not helpers.path_exists(ROFI_CONFIG) then
        notify.error("Rofi config file not found"); return
    end

    local original, err = helpers.read_file(ROFI_CONFIG)
    if not original then notify.error("Failed to read rofi config", err); return end

    local theme_cmd = string.format(
        "(find %s -maxdepth 1 -name '*.rasi' -type f -printf '%%f\\n' 2>/dev/null; "
        .. "find %s -maxdepth 1 -name '*.rasi' -type f -printf '%%f\\n' 2>/dev/null) | sort -V -u",
        helpers.shquote(ROFI_THEMES_CONFIG), helpers.shquote(ROFI_THEMES_LOCAL)
    )
    local tr = helpers.exec(theme_cmd)
    if not tr.success or helpers.trim(tr.stdout) == "" then notify.error("No .rasi themes found"); return end

    local themes = {}
    for line in tr.stdout:gmatch("[^\n]+") do
        if line ~= "" then table.insert(themes, line) end
    end
    if #themes == 0 then notify.error("No themes found"); return end

    local cur_r = helpers.exec(string.format("grep -oP '^\\s*@theme\\s*\"\\K[^\"]+' %s | tail -n1", helpers.shquote(ROFI_CONFIG)))
    local current = helpers.trim(cur_r.stdout ~= "" and basename(helpers.trim(cur_r.stdout)) or "")

    local cur_idx = 0
    for i, t in ipairs(themes) do
        if t == current then cur_idx = i - 1; break end
    end

    local function theme_loop(sel_idx)
        local theme_file = themes[sel_idx + 1]
        if not theme_file then return end

        local theme_path = nil
        for _, dir in ipairs({ ROFI_THEMES_CONFIG, ROFI_THEMES_LOCAL }) do
            local p = dir .. "/" .. theme_file
            if helpers.path_exists(p) then theme_path = p; break end
        end

        if not theme_path then
            helpers.write_file(ROFI_CONFIG, original)
            notify.error("Theme file not found, reverted")
            return
        end

        -- Preview: temporarily inject @theme into config.
        local tilde_path = "~" .. theme_path:sub(#HOME + 1)
        local temp = original:gsub("\n(@theme)", "\n//%1") .. "\n@theme \"" .. tilde_path .. "\"\n"
        helpers.write_file(ROFI_CONFIG, temp)

        local labels = {}
        for _, t in ipairs(themes) do table.insert(labels, t:gsub("%.rasi$", "")) end

        local cmd = string.format(
            "echo %s | rofi -dmenu -i -format 'i' -p 'Rofi Theme' -mesg %s -config %s -selected-row %d -kb-custom-1 'Control+s'",
            helpers.shquote(table.concat(labels, "\n")),
            helpers.shquote("Enter: Preview  ||  Ctrl+S: Apply & Exit  ||  Esc: Cancel"),
            helpers.shquote(ROFI_SELECTOR),
            sel_idx
        )

        helpers.exec_async(cmd, function(exit_code, raw)
            pcall(function()
                local idx = tonumber(helpers.trim(raw or ""))
                if exit_code == 0 and idx ~= nil and idx >= 0 and idx < #themes then
                    theme_loop(idx)
                elseif exit_code == 1 or idx == nil then
                    helpers.write_file(ROFI_CONFIG, original)
                    notify.info("Theme selection cancelled")
                else
                    notify.info("Rofi theme: " .. theme_file:gsub("%.rasi$", ""))
                end
            end)
        end)
    end

    theme_loop(cur_idx)
end

---Animation style picker: copies selected .conf to UserAnimations.conf and refreshes.
function rofi.animations()
    local ok, err = pcall(function()
        proc.kill("rofi")

        if not helpers.dir_exists(ANIMATIONS_DIR) then
            notify.error("Animations directory not found: " .. ANIMATIONS_DIR); return
        end

        local ar = helpers.exec(string.format(
            "find -L %s -maxdepth 1 -type f -name '*.conf' | sed 's|.*/||; s/\\.conf$//' | sort -V",
            helpers.shquote(ANIMATIONS_DIR)
        ))
        if not ar.success or helpers.trim(ar.stdout) == "" then notify.error("No animation files found"); return end

        local anims = {}
        for line in ar.stdout:gmatch("[^\n]+") do
            if line ~= "" then table.insert(anims, line) end
        end
        if #anims == 0 then notify.error("No animation files found"); return end

        menu.pick({
            theme   = ROFI_ANIMATIONS,
            items   = anims,
            message = "This will overwrite UserAnimations.conf",
        }, function(choice, _)
            if not choice then return end

            local src  = ANIMATIONS_DIR  .. "/" .. choice .. ".conf"
            local dest = HYPR_DIR .. "/UserConfigs/UserAnimations.conf"
            local cr   = helpers.exec(string.format("cp %s %s", helpers.shquote(src), helpers.shquote(dest)))
            if not cr.success then notify.error("Failed to copy animation file"); return end

            notify.info(choice .. " animation loaded")
            helpers.delay(0.5, function() refresh.refresh_ui_no_waybar() end)
        end)
    end)

    if not ok then notify.error("Animations picker failed", tostring(err)) end
end

return rofi
