-- Window rules and layer rules
-- Based on UserConfigs/WindowRules.conf

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function tag_by_class(tag_name, patterns)
    for _, pattern in ipairs(patterns) do
        hl.window_rule({
            match = { class = pattern },
            tag = tag_name
        })
    end
end

local function tag_by_title(tag_name, patterns)
    for _, pattern in ipairs(patterns) do
        hl.window_rule({
            match = { title = pattern },
            tag = tag_name
        })
    end
end

-- Apply multiple properties to a single match in one rule
local function rule(match_spec, props)
    local rule_spec = { match = match_spec }
    for k, v in pairs(props) do
        rule_spec[k] = v
    end
    hl.window_rule(rule_spec)
end

-- Apply a property to multiple tagged windows
local function apply_to_tag(tag_name, props)
    rule({ tag = tag_name }, props)
end

-- ============================================
-- TAGS BY CLASS
-- ============================================

tag_by_class("browser", {
    "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin|firefox-nightly)$",
    "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$",
    "^(chrome-.+-Default)$",
    "^([Cc]hromium)$",
    "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$",
    "^(Brave-browser(-beta|-dev|-unstable)?)$",
    "^([Tt]horium-browser|[Cc]achy-browser)$",
    "^(zen-alpha|zen)$",
})

tag_by_class("devtools", { "^(Developer Tools.*)$" })

tag_by_class("notif", { "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" })

tag_by_class("terminal", { "^(Alacritty|kitty|kitty-dropterm)$" })

tag_by_class("email", {
    "^([Tt]hunderbird|org.gnome.Evolution)$",
    "^(eu.betterbird.Betterbird)$"
})

tag_by_class("projects", {
    "^(codium|codium-url-handler|VSCodium)$",
    "^(VSCode|code-url-handler)$",
    "^(jetbrains-.+)$"
})

tag_by_class("screenshare", { "^(com.obsproject.Studio)$" })

tag_by_class("im", {
    "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
    "^([Ff]erdium)$",
    "^([Ww]hatsapp-for-linux)$",
    "^(ZapZap|com.rtosta.zapzap)$",
    "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$",
    "^(teams-for-linux)$",
    "^(im.riot.Riot|Element)$"
})

tag_by_class("games", {
    "^(gamescope)$",
    "^(steam_app_\\d+)$"
})

tag_by_class("gamestore", {
    "^([Ss]team)$",
    "^(com.heroicgameslauncher.hgl)$"
})

tag_by_title("gamestore", { "^([Ll]utris)$" })

tag_by_class("file-manager", {
    "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$",
    "^(app.drey.Warp)$"
})

tag_by_class("wallpaper", { "^([Ww]aytrogen)$" })

tag_by_class("multimedia", { "^([Aa]udacious)$" })

tag_by_class("multimedia_video", { "^([Mm]pv|vlc)$" })

tag_by_class("settings", {
    "^(wihotspot(-gui)?)$",
    "^([Bb]aobab|org.gnome.[Bb]aobab)$",
    "^(gnome-disks|wihotspot(-gui)?)$",
    "^(file-roller|org.gnome.FileRoller)$",
    "^(nm-applet|nm-connection-editor|blueman-manager)$",
    "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
    "^(qt5ct|qt6ct|[Yy]ad)$",
    "(xdg-desktop-portal-gtk)",
    "^(org.kde.polkit-kde-authentication-agent-1)$",
    "^([Rr]ofi)$"
})

tag_by_title("settings", {
    "^(ROG Control)$",
    "(Kvantum Manager)"
})

tag_by_class("viewer", {
    "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$",
    "^(evince)$",
    "^(eog|org.gnome.Loupe)$"
})

-- ============================================
-- KooL APPLICATIONS
-- ============================================

rule(
    { title = "^(Keybind Cheat Sheet)$" },
    { float = true, center = true, size = "600 800" }
)

rule({ title = "^(KooL Hyprland Settings)$" }, { tag = "KooL_Settings" })

rule({ class = "^(nwg-displays|nwg-look)$" }, { tag = "KooL-Settings" })

-- ============================================
-- TAG-BASED OVERRIDES
-- ============================================

apply_to_tag("multimedia_video", { no_blur = true, opacity = "1.0 override" })

-- ============================================
-- POSITION & FLOAT
-- ============================================

-- Thunar dialogs (not main window)
local thunar_dialog = { class = "([Tt]hunar)", title = "negative:.*[Tt]hunar.*" }

rule(thunar_dialog, { float = true, center = true })

rule({ title = "^(ROG Control)$" }, { center = true })

apply_to_tag("KooL-Settings", { float = true, center = true })

rule({ title = "^(Keybindings)$" }, { center = true })

rule(
    { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" },
    { center = true }
)

rule(
    { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" },
    { center = true }
)

rule({ class = "^([Ff]erdium)$" }, { float = true, center = true })

rule({ title = "^(Picture-in-Picture)$" }, { move = "72% 7%" })

-- ============================================
-- MISC FLOAT RULES
-- ============================================

apply_to_tag("wallpaper", { float = true, size = "70% 70%" })

apply_to_tag("settings", { float = true, size = "70% 70%" })

apply_to_tag("viewer", { float = true })

rule({ class = "([Zz]oom|onedriver|onedriver-launcher)$" }, { float = true })

rule(
    { class = "(org.gnome.Calculator)", title = "Calculator" },
    { float = true }
)

rule(
    { class = "^(mpv|com.github.rafostar.Clapper)$" },
    { float = true }
)

rule({ class = "^([Qq]alculate-gtk)$" }, { float = true })

rule(
    { title = "^(Picture-in-Picture)$" },
    { float = true, pin = true, keep_aspect_ratio = true }
)

-- ============================================
-- DIALOGUES
-- ============================================

rule(
    { title = "^(Authentication Required)$" },
    { float = true, center = true }
)

rule(
    { class = "(codium|codium-url-handler|VSCodium)", title = "negative:.*codium.*|.*VSCodium.*" },
    { float = true }
)

rule(
    { class = "^(com.heroicgameslauncher.hgl)$", title = "negative:Heroic Games Launcher" },
    { float = true }
)

rule(
    { class = "^([Ss]team)$", title = "negative:^([Ss]team)$" },
    { float = true }
)

rule(
    { title = "^(Add Folder to Workspace)$" },
    { float = true, center = true, size = "70% 60%" }
)

rule(
    { title = "^(Save As)$" },
    { float = true, center = true, size = "70% 60%" }
)

rule(
    { initial_title = "Open Files" },
    { float = true, size = "70% 60%" }
)

-- ============================================
-- OPACITY
-- ============================================

apply_to_tag("terminal", { opacity = "0.96 0.90" })

rule({ class = "^neovide$" }, { opacity = "0.96 0.90" })

-- ============================================
-- SIZE
-- ============================================

rule(
    { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" },
    { size = "60% 70%" }
)

-- ============================================
-- BLUR & FULLSCREEN
-- ============================================

apply_to_tag("games", { no_blur = true, fullscreen = true })

-- ============================================
-- FOCUS
-- ============================================

rule({ class = "^(jetbrains-.*)" }, { focus_on_activate = false })

rule({ title = "^(wind.*)$" }, { focus_on_activate = false })

-- ============================================
-- LAYER RULES
-- ============================================

local function layer_rule(namespace, props)
    local spec = { match = { namespace = namespace } }
    for k, v in pairs(props) do
        spec[k] = v
    end
    hl.layer_rule(spec)
end

layer_rule("rofi", { blur = true })

layer_rule("notifications", { blur = true })

layer_rule("quickshell:overview", { blur = true, ignore_alpha = 0.5 })

layer_rule("kitty-quick-access", { dim_around = true })

-- ============================================
-- SPECIAL WORKSPACES
-- ============================================

rule({ class = "^(org.signal.Signal)$" }, { workspace = "special:signal" })

rule({ class = "^(org.keepassxc.KeePassXC)$" }, { workspace = "special:keepassxc" })

rule({ initial_title = "^(Writing.*)$" }, { fullscreen = true })
