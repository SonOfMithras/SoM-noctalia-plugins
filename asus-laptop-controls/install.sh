#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Identify the invoking user under sudo, pkexec, or direct execution
PRIMARY_USER="${SUDO_USER:-${PKEXEC_UID:+$(id -un "$PKEXEC_UID")}}"
PRIMARY_USER="${PRIMARY_USER:-$(id -un 1000)}"
USER_HOME=$(getent passwd "$PRIMARY_USER" | cut -d: -f6)

ENABLE_SERVICES=""

for arg in "$@"; do
    case "$arg" in
        --enable)
            ENABLE_SERVICES="yes"
            ;;
        --no-enable)
            ENABLE_SERVICES="no"
            ;;
    esac
done

echo "===== Installing Asus Laptop Controls Services ====="
echo "Installing for user: $PRIMARY_USER"

echo "Installing binaries to /usr/local/bin..."
install -m 755 "$SCRIPT_DIR/bin/asus-laptop-controls-gestures-daemon" "/usr/local/bin/asus-laptop-controls-gestures-daemon"
install -m 755 "$SCRIPT_DIR/asus-laptop-controls-kbd.sh" "/usr/local/bin/asus-laptop-controls-kbd.sh"
install -m 755 "$SCRIPT_DIR/asus-laptop-controls-touchpad.sh" "/usr/local/bin/asus-laptop-controls-touchpad"

echo "Installing system-wide keyboard backlight service..."
install -m 644 "$SCRIPT_DIR/asus-laptop-controls-kbd.service" "/etc/systemd/system/asus-laptop-controls-kbd.service"
systemctl daemon-reload

echo "Installing systemd user unit for gestures daemon..."
mkdir -p /etc/systemd/user
install -m 644 "$SCRIPT_DIR/asus-laptop-controls-gestures.service" "/etc/systemd/user/asus-laptop-controls-gestures.service"

if [ -n "$USER_HOME" ] && [ -d "$USER_HOME/.config/systemd/user" ]; then
    install -o "$PRIMARY_USER" -g "$PRIMARY_USER" -m 644 "$SCRIPT_DIR/asus-laptop-controls-gestures.service" "$USER_HOME/.config/systemd/user/asus-laptop-controls-gestures.service"
fi

echo "Installing udev rules for Touchpad Gestures..."
install -m 644 "$SCRIPT_DIR/99-asus-touchpad.rules" "/etc/udev/rules.d/99-asus-touchpad.rules"
udevadm control --reload-rules && udevadm trigger

# If not specified via flag, ask interactively in a TTY
if [ -z "$ENABLE_SERVICES" ]; then
    if [ -t 0 ]; then
        read -r -p "Do you want to enable and start the services now? [Y/n] " response
        case "$response" in
            [nN][oO]|[nN])
                ENABLE_SERVICES="no"
                ;;
            *)
                ENABLE_SERVICES="yes"
                ;;
        esac
    else
        ENABLE_SERVICES="yes"
    fi
fi

if [ "$ENABLE_SERVICES" = "yes" ]; then
    echo "Enabling keyboard backlight service..."
    systemctl enable --now asus-laptop-controls-kbd.service
    
    echo "Enabling gestures daemon for user $PRIMARY_USER..."
    TARGET_UID=$(id -u "$PRIMARY_USER")
    USER_RUNTIME="/run/user/$TARGET_UID"
    if [ -d "$USER_RUNTIME" ]; then
        runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user daemon-reload 2>/dev/null || true
        runuser -u "$PRIMARY_USER" -- env XDG_RUNTIME_DIR="$USER_RUNTIME" systemctl --user enable --now asus-laptop-controls-gestures.service 2>/dev/null || true
    fi
    echo "Services installed and enabled!"
else
    echo "Services installed without enabling."
    echo "You can enable them later with:"
    echo "  sudo systemctl enable --now asus-laptop-controls-kbd.service"
    echo "  systemctl --user enable --now asus-laptop-controls-gestures.service"
fi

echo "Installation Complete!"
