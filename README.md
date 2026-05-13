# Hyprland Config

> **Based on [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots).** The waybar configs and styles, rofi themes, swaync config, wlogout layout, and AGS overview widget are all derived from that project. The Hyprland config itself (`hypr/`) has been substantially rewritten — migrated from hyprlang + shell scripts to Lua and refactored — but the overall structure and feature set originate there. If you want a batteries-included, actively maintained Hyprland setup, start with Hyprland-Dots directly.

A personal Hyprland 0.55+ configuration written entirely in Lua. Migrated from JaKooLit's 0.54 hyprlang + shell-script setup to take full advantage of the Lua scripting API introduced in 0.55.

This project is both a working Hyprland configuration and an experiment to see how far I can push the use of Lua in Hyprland. It includes some novel concepts, such as an exec+eval loop for handling asynchronous operations in a way that doesn't
block the main compositor loop.

## Features

- **Wallpaper** — swww for images/GIFs, mpvpaper for video; wallust for automatic colour theming across waybar, rofi, swaync, kitty, and SDDM
- **Waybar** — large library of layout/style combinations; live switching via rofi menu
- **Rofi menus** — app launcher, emoji picker, calculator (persistent session), clipboard manager (cliphist), web search, wallpaper selector, animation picker, beats/radio player
- **Screenshots** — grim + slurp (area/window/full/timer), optional swappy annotation; copies to clipboard and saves with open/delete notification actions
- **Dropdown terminal** — scratchpad kitty that follows you across workspaces and monitors
- **Power menu** — wlogout with responsive margin scaling per resolution
- **Display** — brightness (brightnessctl), keyboard backlight, nightlight (hyprsunset), per-monitor support
- **Audio** — volume with OSD, microphone toggle, media controls via playerctl
- **Input** — keyboard layout cycling, touchpad toggle, airplane mode (rfkill)
- **Idle / lock** — hypridle + hyprlock; toggle from keybind or waybar
- **Window rules** — declarative DSL style (`match`, `on_open`, `on_close`, etc.)
- **Keybind viewer** — yad table or searchable rofi list

## Structure

```
hypr/
  hyprland.lua          # entry point: monitors, settings, autostart, keybinds
  binds.lua             # all keybindings
  window-rules.lua      # declarative window/layer rules
  settings.lua          # general, decoration, animation, layout settings
  devices.lua           # device-specific config (touchpad, etc.)
  user-functions/       # feature modules
    audio.lua           #   volume, mic, media
    display.lua         #   brightness, nightlight
    input.lua           #   keyboard layout, touchpad, airplane mode
    rofi.lua            #   all rofi menus
    session.lua         #   lock, logout, screenshots
    system.lua          #   clipboard, idle inhibitor, dropdown terminal, portals
    wallpaper.lua       #   swww/mpvpaper, wallust, SDDM sync
    waybar.lua          #   layout/style switching
    window.lua          #   game mode, window management helpers
  utils/
    helpers.lua         #   exec, async exec, file I/O, safe_call
    icons.lua           #   icon/image path constants
    menu.lua            #   rofi dmenu/input wrappers
    notify.lua          #   domain-specific notify-send wrappers
    proc.lua            #   kill, running, signal, have
    refresh.lua         #   UI restart sequences (waybar, ags, swaync)
    state.lua           #   persistent runtime state (XDG_RUNTIME_DIR)
  scripts/              # shell helpers called from Lua
  data/                 # static data (emoji list, etc.)
rofi/                   # rofi themes and per-menu configs
waybar/                 # waybar configs and stylesheets
wallust/                # wallust templates and config
swaync/                 # swaync config, icons, and stylesheet
wlogout/                # wlogout layout and stylesheet
ags/                    # AGS workspace overview widget
```

## Dependencies

**Required**

| Package | Purpose |
|---------|---------|
| hyprland ≥ 0.55 | compositor |
| waybar | status bar |
| rofi-wayland | menus and launchers |
| swaync | notification center |
| kitty | terminal (default) |
| swww | wallpaper daemon |
| wallust | colour extraction and theming |
| hyprlock | screen locker |
| hypridle | idle daemon |
| wlogout | power menu |
| grim + slurp | screenshots |
| pamixer | volume control |
| playerctl | media control |
| cliphist + wl-clipboard | clipboard manager |
| brightnessctl | screen/keyboard brightness |

**Optional**

| Package | Purpose |
|---------|---------|
| mpvpaper | video wallpapers |
| hyprsunset | nightlight / colour temperature |
| yad | keybind cheat-sheet window |
| swappy | screenshot annotation |
| btop / nvtop | system/GPU monitors (launched from keybind) |
| cava | audio visualiser (waybar module) |

## Installation

1. Install the dependencies above.
2. Back up any existing `~/.config/hypr` directory.
3. Clone this repo and symlink (or copy) the subdirectories into `~/.config/`:
   ```sh
   git clone https://github.com/brettk/hyprland-config ~/.config/hyprland-config
   # then symlink each directory, e.g.:
   ln -s ~/.config/hyprland-config/hypr      ~/.config/hypr
   ln -s ~/.config/hyprland-config/waybar    ~/.config/waybar
   ln -s ~/.config/hyprland-config/rofi      ~/.config/rofi
   # ... and so on for swaync, wlogout, wallust, ags
   ```
4. Edit `hypr/devices.lua` and replace the touchpad device name with yours
   (find it with `hyprctl devices`).
5. Edit `hypr/hyprland.lua` to match your monitor outputs
   (find them with `hyprctl monitors`).
6. Start Hyprland.

## Customisation

The files most likely to need personal adjustment:

- `hypr/devices.lua` — touchpad device identifier
- `hypr/hyprland.lua` — monitor outputs, positions, and scale
- `hypr/binds.lua` — keybindings
- `hypr/window-rules.lua` — per-app rules
- `hypr/user-functions/system.lua` — `TERMINAL` and `FILE_MGR` constants

## Credits

- Rofi themes: [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) (GPL 3.0)
- AGS overview widget: [Aylur/dotfiles](https://github.com/Aylur/dotfiles)
- wlogout icons: [onlinewebfonts.com](https://www.onlinewebfonts.com) (CC BY 3.0)

## License

GPL 3.0 — see [LICENSE](LICENSE.md).
