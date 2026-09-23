#!/bin/bash
# Asus Laptop Controls - Window Manager Aware Touchpad Control
# Supports: Niri, Hyprland (device[asup1207:00-093a:3012-touchpad]), and extensible for Umbriel

ACTION="${1:-toggle}"

detect_wm() {
    local desktop="${XDG_CURRENT_DESKTOP,,}"
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || [ "$desktop" = "hyprland" ]; then
        echo "hyprland"
    elif [ -n "$NIRI_SOCKET" ] || [ "$desktop" = "niri" ]; then
        echo "niri"
    elif [ "$desktop" = "umbriel" ] || pgrep -x umbriel >/dev/null 2>&1; then
        echo "umbriel"
    else
        echo "unknown"
    fi
}

WM=$(detect_wm)

find_niri_config() {
    local primary_user="${SUDO_USER:-$(id -un)}"
    local user_home
    user_home=$(getent passwd "$primary_user" | cut -d: -f6)
    user_home="${user_home:-$HOME}"

    if [ -f "$user_home/.config/niri/conf.d/InOut.kdl" ] && grep -q 'touchpad[[:space:]]*{' "$user_home/.config/niri/conf.d/InOut.kdl"; then
        echo "$user_home/.config/niri/conf.d/InOut.kdl"
        return 0
    elif [ -f "$user_home/.config/niri/config.kdl" ] && grep -q 'touchpad[[:space:]]*{' "$user_home/.config/niri/config.kdl"; then
        echo "$user_home/.config/niri/config.kdl"
        return 0
    fi

    if [ -d "$user_home/.config/niri" ]; then
        local found
        found=$(grep -rnwl --include="*.kdl" "$user_home/.config/niri" -e 'touchpad[[:space:]]*{' 2>/dev/null | head -n 1)
        if [ -n "$found" ] && [ -f "$found" ]; then
            echo "$found"
            return 0
        fi
    fi

    if [ -f "$user_home/.config/niri/conf.d/InOut.kdl" ]; then
        echo "$user_home/.config/niri/conf.d/InOut.kdl"
    elif [ -f "$user_home/.config/niri/config.kdl" ]; then
        echo "$user_home/.config/niri/config.kdl"
    else
        echo ""
    fi
}

reload_niri() {
    local primary_user="${SUDO_USER:-$(id -un)}"
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        local target_uid
        target_uid=$(id -u "$primary_user")
        runuser -u "$primary_user" -- env XDG_RUNTIME_DIR="/run/user/$target_uid" niri msg action load-config-file >/dev/null 2>&1 || true
    else
        niri msg action load-config-file >/dev/null 2>&1 || true
    fi
}

find_umbriel_config() {
    local primary_user="${SUDO_USER:-$(id -un)}"
    local user_home
    user_home=$(getent passwd "$primary_user" | cut -d: -f6)
    user_home="${user_home:-$HOME}"

    if [ -f "$user_home/.config/umbriel/include/inputs.toml" ] && grep -q '\[input.touchpad\]' "$user_home/.config/umbriel/include/inputs.toml"; then
        echo "$user_home/.config/umbriel/include/inputs.toml"
        return 0
    elif [ -f "$user_home/.config/umbriel/config.toml" ] && grep -q '\[input.touchpad\]' "$user_home/.config/umbriel/config.toml"; then
        echo "$user_home/.config/umbriel/config.toml"
        return 0
    fi

    if [ -d "$user_home/.config/umbriel" ]; then
        local found
        found=$(grep -rnwl --include="*.toml" "$user_home/.config/umbriel" -e '\[input.touchpad\]' 2>/dev/null | head -n 1)
        if [ -n "$found" ] && [ -f "$found" ]; then
            echo "$found"
            return 0
        fi
    fi

    if [ -f "$user_home/.config/umbriel/include/inputs.toml" ]; then
        echo "$user_home/.config/umbriel/include/inputs.toml"
    elif [ -f "$user_home/.config/umbriel/config.toml" ]; then
        echo "$user_home/.config/umbriel/config.toml"
    else
        echo ""
    fi
}

reload_umbriel() {
    local primary_user="${SUDO_USER:-$(id -un)}"
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        local target_uid
        target_uid=$(id -u "$primary_user")
        runuser -u "$primary_user" -- env XDG_RUNTIME_DIR="/run/user/$target_uid" umbriel msg config-reload >/dev/null 2>&1 || true
    else
        umbriel msg config-reload >/dev/null 2>&1 || true
    fi
}

get_status() {
    case "$WM" in
        niri)
            local cfg
            cfg=$(find_niri_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                # Scope check strictly to the touchpad { ... } block
                if awk '
                    /^[[:space:]]*touchpad[[:space:]]*\{/ { in_tp = 1; next }
                    in_tp && /^[[:space:]]*\}/ { in_tp = 0 }
                    in_tp && /^[[:space:]]*off([[:space:]]|;|\/\/|$)/ { found = 1 }
                    END { exit(found ? 0 : 1) }
                ' "$cfg"; then
                    echo "disabled"
                    return 1
                else
                    echo "enabled"
                    return 0
                fi
            else
                echo "enabled"
                return 0
            fi
            ;;
        hyprland)
            local res
            res=$(hyprctl getoption "device:asup1207:00-093a:3012-touchpad:enabled" 2>/dev/null)
            if echo "$res" | grep -q "int: 0"; then
                echo "disabled"
                return 1
            else
                echo "enabled"
                return 0
            fi
            ;;
        umbriel)
            local cfg
            cfg=$(find_umbriel_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                if awk '
                    /^\[input\.touchpad\]/ { in_tp = 1; next }
                    /^\[/ { in_tp = 0 }
                    in_tp && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false/ { found = 1 }
                    END { exit(found ? 0 : 1) }
                ' "$cfg"; then
                    echo "disabled"
                    return 1
                else
                    echo "enabled"
                    return 0
                fi
            else
                echo "enabled"
                return 0
            fi
            ;;
        *)
            echo "enabled"
            return 0
            ;;
    esac
}

enable_touchpad() {
    case "$WM" in
        niri)
            local cfg
            cfg=$(find_niri_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                local tmp
                tmp=$(mktemp "${cfg}.tmp.XXXXXX")
                # Only comment out off inside touchpad { ... }
                awk '
                    BEGIN { in_tp = 0 }
                    /^[[:space:]]*touchpad[[:space:]]*\{/ {
                        in_tp = 1
                        print $0
                        next
                    }
                    in_tp {
                        if (/^[[:space:]]*\}/) {
                            in_tp = 0
                            print $0
                            next
                        }
                        if (/^[[:space:]]*off([[:space:]]|;|\/\/|$)/) {
                            sub(/off/, "// off")
                            print $0
                            next
                        }
                    }
                    { print $0 }
                ' "$cfg" > "$tmp" && cat "$tmp" > "$cfg"
                rm -f "$tmp"
                reload_niri
            fi
            ;;
        hyprland)
            hyprctl keyword "device[asup1207:00-093a:3012-touchpad]:enabled" true >/dev/null 2>&1 || true
            ;;
        umbriel)
            local cfg
            cfg=$(find_umbriel_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                local tmp
                tmp=$(mktemp "${cfg}.tmp.XXXXXX")
                awk '
                    BEGIN { in_tp = 0 }
                    /^\[input\.touchpad\]/ {
                        in_tp = 1
                        print $0
                        next
                    }
                    /^\[/ {
                        in_tp = 0
                        print $0
                        next
                    }
                    in_tp {
                        if (/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false/) {
                            sub(/enabled/, "# enabled")
                            print $0
                            next
                        }
                    }
                    { print $0 }
                ' "$cfg" > "$tmp" && cat "$tmp" > "$cfg"
                rm -f "$tmp"
                reload_umbriel
            fi
            ;;
        *)
            echo "Unsupported window manager: $WM" >&2
            return 1
            ;;
    esac
}

disable_touchpad() {
    case "$WM" in
        niri)
            local cfg
            cfg=$(find_niri_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                local tmp
                tmp=$(mktemp "${cfg}.tmp.XXXXXX")
                # Only toggle or insert off strictly within touchpad { ... }
                awk '
                    BEGIN { in_tp = 0; has_off = 0 }
                    /^[[:space:]]*touchpad[[:space:]]*\{/ {
                        in_tp = 1
                        print $0
                        next
                    }
                    in_tp {
                        if (/^[[:space:]]*\}/) {
                            if (!has_off) {
                                match($0, /^[[:space:]]*/)
                                indent = substr($0, RSTART, RLENGTH) "    "
                                print indent "off"
                            }
                            in_tp = 0
                            print $0
                            next
                        }
                        if (/^[[:space:]]*\/\/[[:space:]]*off([[:space:]]|;|\/\/|$)/) {
                            has_off = 1
                            sub(/\/\/[[:space:]]*off/, "off")
                            print $0
                            next
                        }
                        if (/^[[:space:]]*off([[:space:]]|;|\/\/|$)/) {
                            has_off = 1
                            print $0
                            next
                        }
                    }
                    { print $0 }
                ' "$cfg" > "$tmp" && cat "$tmp" > "$cfg"
                rm -f "$tmp"
                reload_niri
            fi
            ;;
        hyprland)
            hyprctl keyword "device[asup1207:00-093a:3012-touchpad]:enabled" false >/dev/null 2>&1 || true
            ;;
        umbriel)
            local cfg
            cfg=$(find_umbriel_config)
            if [ -n "$cfg" ] && [ -f "$cfg" ]; then
                local tmp
                tmp=$(mktemp "${cfg}.tmp.XXXXXX")
                awk '
                    BEGIN { in_tp = 0; has_enabled = 0 }
                    /^\[input\.touchpad\]/ {
                        in_tp = 1
                        print $0
                        next
                    }
                    /^\[/ {
                        if (in_tp && !has_enabled) {
                            print "enabled = false"
                        }
                        in_tp = 0
                        print $0
                        next
                    }
                    in_tp {
                        if (/^[[:space:]]*#[[:space:]]*enabled[[:space:]]*=[[:space:]]*false/) {
                            has_enabled = 1
                            sub(/#.*enabled/, "enabled")
                            print $0
                            next
                        }
                        if (/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false/) {
                            has_enabled = 1
                            print $0
                            next
                        }
                        if (/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true/) {
                            has_enabled = 1
                            sub(/true/, "false")
                            print $0
                            next
                        }
                    }
                    { print $0 }
                    END {
                        if (in_tp && !has_enabled) {
                            print "enabled = false"
                        }
                    }
                ' "$cfg" > "$tmp" && cat "$tmp" > "$cfg"
                rm -f "$tmp"
                reload_umbriel
            fi
            ;;
        *)
            echo "Unsupported window manager: $WM" >&2
            return 1
            ;;
    esac
}

case "$ACTION" in
    status)
        get_status
        ;;
    enable)
        enable_touchpad
        ;;
    disable)
        disable_touchpad
        ;;
    toggle)
        if get_status >/dev/null; then
            disable_touchpad
        else
            enable_touchpad
        fi
        ;;
    *)
        echo "Usage: $0 {status|enable|disable|toggle}"
        exit 1
        ;;
esac
