#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIMARY_USER="${SUDO_USER:-${PKEXEC_UID:+$(id -un "$PKEXEC_UID")}}"
PRIMARY_USER="${PRIMARY_USER:-$(id -un 1000)}"
USER_HOME=$(getent passwd "$PRIMARY_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$PRIMARY_USER")
USER_RUNTIME="/run/user/$TARGET_UID"

MODE="uninstall"
for arg in "$@"; do
    case "$arg" in
        --disable)
            MODE="disable"
            ;;
        --uninstall)
            MODE="uninstall"
            ;;
    esac
done

if [ "$MODE" = "disable" ]; then
    echo "===== Disabling Asus Laptop Controls Services ====="
    echo "Stopping and disabling system keyboard backlight service..."
    systemctl stop asus-laptop-controls-kbd.service 2>/dev/null || true
    systemctl disable asus-laptop-controls-kbd.service 2>/dev/null || true

    echo "Stopping and disabling user gestures daemon..."
    if [ -d "$USER_RUNTIME" ]; then
        runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user stop asus-laptop-controls-gestures.service 2>/dev/null || true
        runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user disable asus-laptop-controls-gestures.service 2>/dev/null || true
    fi
    echo "Services disabled successfully."
    exit 0
fi

echo "===== Uninstalling Asus Laptop Controls Services ====="
echo "Uninstalling for user: $PRIMARY_USER"

echo "Stopping and disabling services..."
systemctl stop asus-laptop-controls-kbd.service 2>/dev/null || true
systemctl disable asus-laptop-controls-kbd.service 2>/dev/null || true

if [ -d "$USER_RUNTIME" ]; then
    runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user stop asus-laptop-controls-gestures.service 2>/dev/null || true
    runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user disable asus-laptop-controls-gestures.service 2>/dev/null || true
    runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user daemon-reload 2>/dev/null || true
fi

echo "Removing systemd service units..."
rm -f /etc/systemd/system/asus-laptop-controls-kbd.service
rm -f /etc/systemd/user/asus-laptop-controls-gestures.service
if [ -n "$USER_HOME" ]; then
    rm -f "$USER_HOME/.config/systemd/user/asus-laptop-controls-gestures.service"
fi
systemctl daemon-reload

echo "Removing udev rules..."
rm -f /etc/udev/rules.d/99-asus-touchpad.rules
udevadm control --reload-rules && udevadm trigger

echo "Removing binaries..."
rm -f /usr/local/bin/asus-laptop-controls-gestures-daemon
rm -f /usr/local/bin/asus-laptop-controls-kbd.sh
rm -f /usr/local/bin/asus-laptop-controls-touchpad

echo "Uninstall Complete!"
