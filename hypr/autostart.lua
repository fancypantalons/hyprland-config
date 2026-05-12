-- Autostart applications
-- Based on Startup_Apps.conf


-- Helper to cache the current bind list for show_binds() (avoids hyprctl deadlock)
local function cache_binds()
  hl.exec_cmd("mkdir -p ~/.cache/hypr && hyprctl binds -j | jq -r '.[] | select(.submap == \"\" and .catch_all == false and .mouse == false) | [(.modmask | tostring), .key, .description, .dispatcher, .arg] | @tsv' > ~/.cache/hypr/binds.tsv")
end

hl.on("hyprland.start", function()
  -- Make sure any running tmux instances don't hold on to this old variable
  hl.exec_cmd("tmux setenv -g HYPRLAND_INSTANCE_SIGNATURE \"" .. os.getenv("HYPRLAND_INSTANCE_SIGNATURE") .. "\"")
  
  -- Fire up an ssh agent
  local sock = os.getenv("SSH_AUTH_SOCK")
      or ("/run/user/" .. (os.getenv("UID") or "1000") .. "/ssh-agent.sock")
  hl.exec_cmd("ssh-agent -D -a " .. sock)
  
  -- Wallpaper stuff
  hl.exec_cmd("swww-daemon --format xrgb")
  
  -- Cursor stuff
  hl.exec_cmd("hyprctl setcursor Adwaita 24")
  
  -- DBus environment
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  
  -- XDG Desktop Portals (for screensharing, file opening, etc.)
  user.system.start_portals()

  -- Polkit
  user.system.start_polkit()
  
  -- Startup apps
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("swaync")
  hl.exec_cmd("ags")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("waybar")
  hl.exec_cmd("qs")  -- quickshell AGS Desktop Overview alternative
  
  -- Clipboard manager
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  
  -- Starting hypridle to start hyprlock
  hl.exec_cmd("hypridle")

  -- Cache binds for show_binds() to avoid hyprctl deadlock
  cache_binds()
  
  -- Special workspace for keepassxc
  hl.exec_cmd("keepassxc", { workspace = "special:keepassxc" })
end)

-- Re-cache binds after every config reload so show_binds() stays current
hl.on("config.reloaded", cache_binds)
