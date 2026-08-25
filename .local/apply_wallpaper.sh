#!/usr/bin/env bash

WALLPAPER="$1"

[ -f "$WALLPAPER" ] || exit 1

# 1. Change wallpaper via awww
awww img "$WALLPAPER" \
    --transition-type grow \
    --transition-pos center \
    --transition-fps 60 \
    --transition-step 90

# 2. Extract colors with Pywal
wal -i "$WALLPAPER" -n -q

# 3. Force Waybar to reload its CSS stylesheet
pkill -USR2 waybar

# 4. Reload SwayNC if running
if pgrep -x "swaync" > /dev/null; then
    swaync-client -R -rs
fi