# Asus Laptop Controls Plugin

A Noctalia v5 plugin providing a control center for ASUS laptops (ROG, TUF, ZenBook) to manage platform power profiles, battery thresholds, smart touchpad edge gestures, and keyboard backlight idle auto-dimming.

## Features

- **Platform Power Profiles**: Switch between ASUS Platform Profiles (**Quiet**, **Balanced**, **Performance**) from the control panel or cycle through them with the quick toggle shortcut button.
- **AC & Battery Profiles**: Configure distinct profiles for AC power and battery mode.
- **Battery Health Thresholds**: Set a maximum charge limit percentage (20%–100%) to preserve battery longevity.
- **One-Shot Charge**: Temporarily charge to 100% for a single cycle before returning to your configured limit.
- **Keyboard Backlight Manager**: Control backlight level (`Off`, `Low`, `Med`, `High`) and configure idle auto-dimming timeout (from 1s up to 10m) via a responsive dropdown.
- **Smart Touchpad Edge Gestures**: Swipe along touchpad edges to adjust display brightness (left edge), system volume (right edge), or media playback (top edge).
- **Multiple UI Components**: Includes an attached control panel (`panel`), a status bar widget that opens the panel (`asusctl`), an informational desktop widget (`asusctl_desktop`), and a profile-cycling shortcut button (`asusctl_toggle_button`).
- **Service Management**: Live status, enable/disable switches, and one-click restart for background daemons directly inside the panel.

## Dependencies

- **`asusctl`** & **`asusd`**: Communicates with the ASUS WMI hardware layer for power profiles and battery thresholds.
- **`brightnessctl`**: Controls keyboard and display backlight.
- **`jq`**: Parses configuration settings for the background keyboard backlight daemon.
- **`libevdev`**: Used by the background gestures daemon to capture edge swipe events.

---

## Commands Reference

### Noctalia Panel & IPC Commands

Control the Asus Laptop Controls panel, toggle touchpad, or open settings from keybindings, scripts, or the terminal:

```bash
# Toggle the panel (recommended for keyboard shortcuts / compositor keybindings)
noctalia msg panel-toggle SoM/asus-laptop-controls:panel

# Open the panel
noctalia msg panel-open SoM/asus-laptop-controls:panel

# Close the panel
noctalia msg panel-close SoM/asus-laptop-controls:panel

# Toggle touchpad via Noctalia service IPC
noctalia msg plugin:SoM/asus-laptop-controls:touchpad toggle

# Open the plugin settings window in Noctalia
noctalia msg settings-open-plugin SoM/asus-laptop-controls
```

> [!NOTE]
> Noctalia IPC handles shell panels, settings, volume, brightness, media playback, and touchpad toggle via plugin service. Touchpad state can also be toggled directly at the compositor level (`hyprctl` or `niri`) or via kernel input inhibit; see [Touchpad Control](#touchpad-control-enable--disable) below for full commands.

### Background Services Management

Commands to inspect, restart, and manage the installed background daemons:

#### 1. Touchpad Edge Gestures Daemon (`asus-laptop-controls-gestures.service`)
Runs as a systemd **user service** to capture edge swipe inputs and trigger Noctalia actions:

```bash
# Check service status
systemctl --user status asus-laptop-controls-gestures.service

# Restart service (picks up updated gestures or configuration)
systemctl --user restart asus-laptop-controls-gestures.service

# Stop / Start service
systemctl --user stop asus-laptop-controls-gestures.service
systemctl --user start asus-laptop-controls-gestures.service

# Enable / Disable service at user login
systemctl --user enable --now asus-laptop-controls-gestures.service
systemctl --user disable --now asus-laptop-controls-gestures.service

# View live daemon logs
journalctl --user -u asus-laptop-controls-gestures.service -f
```

#### 2. Keyboard Backlight Idle Daemon (`asus-laptop-controls-kbd.service`)
Runs as a systemd **system service** to monitor keyboard activity and auto-dim the backlight when idle:

```bash
# Check service status
systemctl status asus-laptop-controls-kbd.service

# Restart service
sudo systemctl restart asus-laptop-controls-kbd.service

# Stop / Start service
sudo systemctl stop asus-laptop-controls-kbd.service
sudo systemctl start asus-laptop-controls-kbd.service

# Enable / Disable service
sudo systemctl enable --now asus-laptop-controls-kbd.service
sudo systemctl disable --now asus-laptop-controls-kbd.service

# View live daemon logs
journalctl -u asus-laptop-controls-kbd.service -f
```

---

### Direct Hardware CLI Controls

Commands to inspect or control ASUS hardware directly from the command line:

#### Power Profiles (`asusctl`)
```bash
# Get active platform profile and AC/Battery settings
asusctl profile get

# Set active profile (Quiet, Balanced, Performance)
asusctl profile set Quiet
asusctl profile set Balanced
asusctl profile set Performance

# Set profiles specifically for AC or Battery power
asusctl profile set -a Performance
asusctl profile set -b Quiet
```

#### Battery Thresholds (`asusctl`)
```bash
# Check battery health and charge limit
asusctl battery info

# Set maximum battery charge limit percentage (e.g. 80%)
asusctl battery limit 80

# Trigger a one-shot 100% charge
asusctl battery oneshot
```

#### Keyboard Backlight (`brightnessctl`)
```bash
# Get current keyboard backlight level (0 to 3)
brightnessctl -d asus::kbd_backlight get

# Set keyboard backlight level
brightnessctl -sd asus::kbd_backlight set 0   # Off
brightnessctl -sd asus::kbd_backlight set 1   # Low
brightnessctl -sd asus::kbd_backlight set 2   # Medium
brightnessctl -sd asus::kbd_backlight set 3   # High
```

#### Touchpad Control (Enable / Disable)

The plugin includes an automatic window manager detection tool (`asus-laptop-controls-touchpad`) that detects whether you are running **Niri** or **Hyprland** (and extensible for **Umbriel**) and executes the appropriate compositor method:

```bash
# Toggle touchpad on/off (automatically detects active WM/compositor)
asus-laptop-controls-touchpad toggle

# Check current touchpad status (prints 'enabled' or 'disabled')
asus-laptop-controls-touchpad status

# Force enable or disable
asus-laptop-controls-touchpad enable
asus-laptop-controls-touchpad disable
```

> [!TIP]
> You can toggle the touchpad directly inside the Noctalia **Asus Laptop Controls** panel under the **Touchpad & Gestures** section, or bind the CLI tool to your laptop's touchpad toggle key (`XF86TouchpadToggle` / `Fn+F10`):
> - **In Niri** (`~/.config/niri/conf.d/keybinds.kdl`):
>   ```kdl
>   XF86TouchpadToggle { spawn "asus-laptop-controls-touchpad" "toggle"; }
>   ```
> - **In Hyprland** (`~/.config/hypr/hyprland.conf`):
>   ```bash
>   bind = , XF86TouchpadToggle, exec, asus-laptop-controls-touchpad toggle
>   ```

##### Under the Hood: Compositor & Kernel Methods
ASUS ZenBook/ROG touchpads identify as `ASUP1207:00 093A:3012 Touchpad` (or compositor device identifier `asup1207:00-093a:3012-touchpad`):

1. **Niri Compositor**: Manages `~/.config/niri/conf.d/InOut.kdl` inside `input.touchpad` by toggling `off` and reloading via `niri msg action load-config-file`.
2. **Hyprland (`hyprctl`)**: Uses the device name method from `NiriAsus`:
   ```bash
   hyprctl keyword "device[asup1207:00-093a:3012-touchpad]:enabled" <true|false>
   ```
3. **Umbriel**: Window manager detection is recognized and ready for compositor input integration.
4. **Kernel Subsystem (Fallback)**: Directly controls `/sys/devices/.../input*/inhibited` to suspend event delivery at the Linux driver level.

---

### Supported Gesture Action Commands

Action commands executed by edge gestures (configured in `~/.local/share/noctalia/plugins/asus-laptop-controls/config.json` or Plugin Settings):

```bash
# Display Brightness (with native Noctalia OSD)
noctalia msg brightness-up
noctalia msg brightness-down

# System Volume (with native Noctalia OSD)
noctalia msg volume-up
noctalia msg volume-down

# Media Playback
noctalia msg media toggle
noctalia msg media next
noctalia msg media previous
```

---

### Installation & Uninstallation Scripts

Run the included scripts to install or remove background services, binaries, and udev rules (via `pkexec` for graphical polkit prompt, or `sudo` for terminal):

```bash
# Install binaries, udev rules, and background services
pkexec bash ./install.sh --enable
# or in a terminal:
sudo bash ./install.sh --enable

# Install without enabling automatically
pkexec bash ./install.sh --no-enable
# or in a terminal:
sudo bash ./install.sh --no-enable

# Completely uninstall background services, binaries, and udev rules
pkexec bash ./uninstall.sh
# or in a terminal:
sudo bash ./uninstall.sh
```

