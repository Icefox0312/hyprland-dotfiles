#!/bin/bash
# Restart Waybar cleanly.
# Waits for the old process to actually exit before starting a new one,
# so you never get two waybars racing for the same layer-shell surface.
# Logs to /tmp/waybar.log so a broken config.jsonc doesn't fail silently.

if pgrep -x waybar >/dev/null; then
    pkill -x waybar
    while pgrep -x waybar >/dev/null; do
        sleep 0.1
    done
fi

waybar >/tmp/waybar.log 2>&1 &
disown
