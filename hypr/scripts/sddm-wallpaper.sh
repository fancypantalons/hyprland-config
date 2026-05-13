#!/bin/bash
# Set the current wallpaper and wallust-derived colours on the simple_sddm_2 theme.
# Called from wallpaper.lua via:  kitty -e bash sddm-wallpaper.sh <wallpaper_path> <sddm_theme_dir> <rofi_wallust_rasi>

set -euo pipefail

WALLPAPER="$1"
SDDM_THEME_DIR="$2"           # e.g. /usr/share/sddm/themes/simple_sddm_2
ROFI_WALLUST="$3"             # e.g. ~/.config/rofi/wallust/colors-rofi.rasi
SDDM_CONF="${SDDM_THEME_DIR}/theme.conf"
BACKGROUNDS="${SDDM_THEME_DIR}/Backgrounds"

echo "Enter your password to update SDDM wallpaper and colours"

extract() {
    grep -oP "$1:\\s*\\K#[A-Fa-f0-9]+" "$ROFI_WALLUST" 2>/dev/null | head -1 || echo "$2"
}

color1=$(extract  "color1"  "#ffffff")
color0=$(extract  "color0"  "#000000")
color14=$(extract "color14" "#ffffff")
color10=$(extract "color10" "#ffffff")
color12=$(extract "color12" "#ffffff")
color13=$(extract "color13" "#ffffff")

sed_color() {
    sudo sed -i "s/${1}=\"#.*\"/${1}=\"${2}\"/" "$SDDM_CONF"
}

# Apply colours
for key in HeaderTextColor DateTextColor TimeTextColor DropdownSelectedBackgroundColor \
           SystemButtonsIconsColor SessionButtonTextColor VirtualKeyboardButtonTextColor; do
    sed_color "$key" "$color13"
done
sed_color HighlightBackgroundColor "$color12"
sed_color LoginFieldTextColor       "$color12"
sed_color PasswordFieldTextColor    "$color12"
sed_color DropdownBackgroundColor   "$color1"
sed_color HighlightTextColor        "$color10"
sed_color PlaceholderTextColor      "$color7"
sed_color UserIconColor             "$color7"
sed_color PasswordIconColor         "$color7"

# Copy wallpaper
sudo cp -f "$WALLPAPER" "$BACKGROUNDS/default" || true
[ -e "$BACKGROUNDS/default.jpg" ] && sudo cp -f "$WALLPAPER" "$BACKGROUNDS/default.jpg" || true
[ -e "$BACKGROUNDS/default.png" ] && sudo cp -f "$WALLPAPER" "$BACKGROUNDS/default.png" || true

notify-send "SDDM" "Background updated"
