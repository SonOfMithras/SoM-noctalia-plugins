# Strix Powermon

A power monitoring plugin for Ryzen APU's, designed with laptops in mind so I deliberately tried to keep it light on resources.

## Features
- **Granular Monitoring**: Track specific power draw metrics including CPU, GPU, NPU, and total System (Battery) power, you can choose to disable any of them in the plugin settings.
- **Multiple Widget Views**: Separated into individual panel widgets to display Battery percentage and estimated time (either to Full or Empty), System Power Draw, CPU Power, GPU Power, or NPU Power. You can choose to disable the glyph on any of them as well.
- **Tooltip Statistics**: View live charts and combined statistics directly from the widget tooltip, logs in RAM to reduce the albeit minimal I/O overhead and wear.
- **Customizable Commands**: Adjust the CLI commands used to fetch sensor data through the plugin settings.

## Dependencies
- **`lm-sensors`**: Used for CPU and Battery power telemetry (`sensors -j`).
- **`upower`**: Used to track battery discharging rates and time-to-empty/full.
- **`xrt-smi` (Optional)**: Required if you want to monitor Ryzen NPU power draw.

## Limitations
- **Hardware Specific Paths**: GPU power draw relies on reading from `/sys/class/drm/card*/device/hwmon/...`. Depending on your specific AMD/Nvidia GPU and kernel version, this path might change or require tweaking in the plugin settings. For NVIDIA dedicated GPUs (dGPU), you can set the dGPU command to: `nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits`
- **NPU Compatibility**: The NPU tracking defaults to `xrt-smi` which requires the AMD XRT drivers. It may not work on non-Ryzen AI chips or unconfigured systems, this can be configured in the plugin settings as well.
- **Update Frequency**: Fetching data using CLI commands (like `sensors -j`) has a slight overhead. The default refresh interval is 15 seconds to minimize battery impact from the polling itself.
- **0% Desktop Widget**: Disabling both Estimated time to... and Battery percentage will result in the widget showing "0%" on the desktop widget. Luckily it is customizable so it is not much of an issue, and if you want it displayed, have either battery percentage or estimated time enabled in the plugin settings.

## Commands
- **Toggle Panel**: You can open or close the Powermon panel at any time using the following command. This is especially useful for setting up custom keybindings.
  ```bash
  noctalia msg panel-toggle SoM/strix-powermon:panel
  ```
