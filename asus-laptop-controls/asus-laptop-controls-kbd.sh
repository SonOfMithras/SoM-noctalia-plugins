#!/bin/bash

# Find the raw keyboard event device
KBD_DEV=$(ls /dev/input/by-path/*-event-kbd | head -n 1)
if [ -z "$KBD_DEV" ]; then
    echo "No keyboard device found in /dev/input/by-path/"
    exit 1
fi

PRIMARY_USER=$(id -un 1000)
CONFIG_FILE="/home/$PRIMARY_USER/.local/share/noctalia/plugins/asus-laptop-controls/config.json"

DIMMED=0

# Initial startup brightness
INITIAL_BRIGHTNESS=$(jq -r '.kbd_brightness // 1' "$CONFIG_FILE" 2>/dev/null || echo 1)
brightnessctl -sd asus::kbd_backlight set "$INITIAL_BRIGHTNESS" 2>/dev/null || true

while true; do
    # Read config dynamically each iteration
    IDLE_LIMIT=$(jq -r '.kbd_timeout // 15' "$CONFIG_FILE" 2>/dev/null || echo 15)
    KBD_BRIGHTNESS=$(jq -r '.kbd_brightness // 1' "$CONFIG_FILE" 2>/dev/null || echo 1)

    # `dd` blocks until input is received. 
    # `timeout` kills it after IDLE_LIMIT seconds.
    if timeout "$IDLE_LIMIT" dd if="$KBD_DEV" bs=24 count=1 >/dev/null 2>&1; then
        # Key pressed
        if [ "$DIMMED" -eq 1 ]; then
            brightnessctl -sd asus::kbd_backlight set "$KBD_BRIGHTNESS" 2>/dev/null || true
            DIMMED=0
        fi
        sleep 0.1
    else
        # Timeout reached, no keys pressed
        if [ "$DIMMED" -eq 0 ]; then
            brightnessctl -sd asus::kbd_backlight set 0 2>/dev/null || true
            DIMMED=1
        fi
    fi
done
