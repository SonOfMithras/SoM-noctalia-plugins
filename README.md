# SoM Noctalia Plugins

This repository contains a collection of custom plugins for Noctalia, developed by SoM. These plugins provide additional functionality and monitoring capabilities for your desktop environment.

## Included Plugins

### 1. [Strix Powermon](./strix-powermon)
**ID:** `SoM/strix-powermon`

A lightweight, configurable power monitor designed specifically for Ryzen APUs and laptops. It provides granular telemetry without heavily taxing system resources.

**Key Features:**
- Monitor CPU, dedicated GPU (dGPU), NPU, and total System (Battery) power draw.
- Separate panel widgets for each metric or combined tooltips with live charts.
- Configurable commands to fetch sensor data depending on your specific hardware.
- Tracks battery percentage and time-to-full/empty.

**Dependencies:** `lm-sensors`, `upower`, `xrt-smi` (optional for NPU).

### 2. [AsusCtl](./asusctl)
**ID:** `SoM/asusctl`

A plugin to control ASUS Armoury Crate settings directly from your desktop or panel. Perfect for managing power profiles and battery health on supported ASUS laptops.

**Key Features:**
- Toggle and cycle between ASUS Platform Profiles (Quiet, Balanced, Performance).
- Auto-switch profiles based on AC/Battery state.
- Set a maximum battery charge threshold to preserve battery health.
- One-shot charge capability to temporarily override the battery limit for a full charge.

**Dependencies:** `asusctl` and `asusd` service running on a compatible ASUS laptop.

### 3. [Asus Laptop Controls](./asus-laptop-controls)
**ID:** `SoM/asus-laptop-controls`

A comprehensive control center plugin for ZenBook laptops. Unifies platform power profiles, battery longevity thresholds, smart touchpad edge gestures, keyboard backlight idle auto-dimming, and window manager-aware touchpad toggling.

**Key Features:**
- Switch ASUS Platform Profiles (Quiet, Balanced, Performance) with dedicated AC and Battery defaults.
- Set battery health charge limits (20%–100%) and one-shot 100% override charge mode.
- Keyboard backlight brightness control with an automated background idle auto-dimming daemon.
- Smart touchpad edge gestures (left edge for brightness, right edge for volume, top edge for media) via a dedicated background daemon.
- Window manager-aware touchpad enable/disable toggle supporting Niri, Hyprland, and extensible for Umbriel.
- Multiple interface components: full attached control panel, status bar widget, desktop widget, and profile cycle shortcut button.
- Built-in background service management (live status, toggle, and restart) directly from the panel.

**Dependencies:** `asusctl`, `asusd`, `brightnessctl`, `jq`, `libevdev`.

---

*See the individual `README.md` in each plugin's folder for more detailed information and configuration instructions.*
