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

---

*See the individual `README.md` in each plugin's folder for more detailed information and configuration instructions.*
