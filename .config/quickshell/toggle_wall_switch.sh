#!/usr/bin/env bash

# Check if the wallpaper switcher is running
if pgrep -f "[w]all-switch/shell.qml" > /dev/null; then
    pkill -f "[w]all-switch/shell.qml"
else
    qs -p ~/.config/quickshell/wall-switch/shell.qml &
fi
