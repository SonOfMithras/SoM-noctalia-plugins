# AsusCtl Plugin

A Noctalia plugin to control *some* ASUS Armoury Crate settings directly from a widget on your desktop or panel.

## Features
- **Profile Management**: Quickly toggle and cycle between ASUS Platform Profiles (Quiet, Balanced, Performance). 
- **Auto Profile Switching**: If you have '''change_platform_profile_on_battery: true,''' and '''change_platform_profile_on_ac: true,''' in your config, the plugin will be able to pick which profile is used on battery or while plugged in.
- **Battery Thresholds**: Set a maximum battery charge limit to preserve battery health.
- **One-Shot Charge**: Trigger a one-time full charge overriding the limit, temporarily sets the battery charge limit to 100% for a single charge cycle.

## Dependencies
This plugin relies on the underlying system utility to communicate with the ASUS hardware.
- **`asusctl`**: Must be installed and the `asusd` service must be running. They both require the asus_wmi module to be loaded as well. 

## Limitations
- **Hardware Requirement**: Only functions on supported ASUS laptops (ROG, TUF, etc.) that are compatible with `asusctl`.
- **System Service**: Requires elevated privileges handled by `asusd`; if the daemon is not running, the plugin cannot read or modify settings.
- **Battery Limit Granularity**: Some older ASUS laptops only support specific charge limit steps (e.g., 60%, 80%, 100%). The slider attempts to respect 5% intervals, but the hardware may round to the nearest supported threshold.

## Commands
- **Toggle Panel**: You can open or close the AsusCtl panel at any time using the following command. This is especially useful for setting up custom keybindings.
  ```bash
  noctalia msg panel-toggle SoM/asusctl:panel
  ```
