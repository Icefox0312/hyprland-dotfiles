#!/usr/bin/env bash

# Check if the launcher is running
if pgrep -f "[a]pp-launcher/shell.qml" > /dev/null; then
    # If running, kill it
    pkill -f "[a]pp-launcher/shell.qml"
else
    # If not running, launch it
    qs -p ~/.config/quickshell/app-launcher/shell.qml &
fi
