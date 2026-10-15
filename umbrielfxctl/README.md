# UmbrielFXctl

**Plugin ID:** `SoM/umbrielfxctl`  
**API Level:** `28`

A modular Noctalia plugin to discover, manage, and toggle community GLSL shaders and animations in the **Umbriel Wayland compositor** across **6 independent slots**.

> [!NOTE]
> This is a companion plugin to the [Community Umbriel Shaders collection](https://github.com/noctalia-dev/community-umbriel-shaders/tree/main).
> Simply follow the instructions below to download the whole collection, and this plugin will handle the rest!

---

## Quick Setup: Shaders Collection

To get started, clone the [community-umbriel-shaders](https://github.com/noctalia-dev/community-umbriel-shaders/tree/main) repository into your Umbriel config directory:

```bash
# Clone the complete community shaders collection
mkdir -p ~/.config/umbriel/shaders
git clone https://github.com/noctalia-dev/community-umbriel-shaders.git \
  ~/.config/umbriel/shaders/community
```

Once the folder is present, **this plugin handles everything else automatically**:
- Automatically creates the 6 independent effect configuration files in `~/.config/umbriel/`.
- Automatically links all 6 files into `[include.optional]` inside `~/.config/umbriel/config.toml`.
- Discovers all presets, displays preview thumbnails, and enables live hot-reloading with zero manual editing.

---

## Features

- **6-Slot Modular Architecture:**
  - Automatically creates and manages 6 separate Umbriel configuration files:
    - `~/.config/umbriel/umbriel-effect-workspace.toml`: Workspace transitions (names prepended with `workspace-`, plus reveal presets like `witching-hour` and `vampire-blood-wash`).
    - `~/.config/umbriel/umbriel-effect-in-out.toml`: Window opening (`windows_in`) and closing (`windows_out`) lifecycle animations.
    - `~/.config/umbriel/umbriel-effect-move.toml`: Window dragging/resizing deformation shaders (`windows_move`).
    - `~/.config/umbriel/umbriel-effect-misc.toml`: Misc window post-processing shaders, textures, overlays, and screen FX.
    - `~/.config/umbriel/umbriel-effect-border.toml`: Focused window border decoration shaders.
    - `~/.config/umbriel/umbriel-effect-cursor.toml`: Interactive cursor trail and glow shaders.
  - Automatically registers all 6 files in the `[include.optional]` section of `~/.config/umbriel/config.toml`.
  - **Simultaneous Activation:** Enable **one effect per slot simultaneously** (e.g. Workspace Burn + Wobbly Move + VHS In/Out + CRT Misc + Glow Cursor + Rainbow Border)!
- **Clean Icon-Driven UI with Relative Path Tooltips:**
  - Card action buttons are sleek, icon-only buttons.
  - Tooltips display the effect title, relative path from Umbriel config root (`shaders/community/...`), and mouse actions.
  - Clicking an unselected card's play button applies that effect to its respective slot without affecting other slots.
  - Clicking an active card's checkmark button disables that slot.
- **Right-Click to Open in File Manager:**
  - Right-clicking any effect card, thumbnail, or button opens that effect's subfolder directly in the user's default file manager (Dolphin via `xdg-open`).
- **Categorized 6-Tab Navigation:**
  - Filter by **Workspace**, **In/Out**, **Move**, **Border**, **Cursor**, and **Misc FX**.
  - Tabs display active indicator dots (`•`) when an effect is running in that slot.
  - Status banner displays the active preset for the current tab with a slot-specific clear button.
- **Bar Widget & Control Center Shortcut:**
  - Bar widget dynamically reflects active count (e.g. `2 FX` or the active preset name) and opens the panel on click.
  - Control center shortcut tile illuminates whenever any effect is active.
- **One-Click Config Cleanup & Resetup:**
  - Dedicated **Setup / Resetup** button (`file-plus` icon) in the header and on missing-slot banners to recreate all 6 files and register them into `[include.optional]`.
  - Dedicated **Remove Configs** button (`file-x` icon) directly in the panel header next to the Close button.
  - Deletes all 6 generated `umbriel-effect-*.toml` files from `~/.config/umbriel/` and unregisters them from `[include.optional]` in `~/.config/umbriel/config.toml`.
  - Both actions are callable via Noctalia IPC plugin commands (`noctalia msg plugin ...`) or directly from the CLI backend.

---

## Architectural Principles & Umbriel Integration

### 1. Modular Includes Model

In `~/.config/umbriel/config.toml`, Umbriel defines optional include files:

```toml
[include.optional]
files = [
    "noctalia.toml",
    "umbriel-effect-workspace.toml",
    "umbriel-effect-in-out.toml",
    "umbriel-effect-move.toml",
    "umbriel-effect-misc.toml",
    "umbriel-effect-border.toml",
    "umbriel-effect-cursor.toml"
]
```

By separating effects into 6 files:
1. **Zero Table Collisions:** Each file contains only its respective table (e.g. `[animation.workspaces]` or `[effects] cursor = ...`). TOML's rule against duplicate table declarations is never violated.
2. **Independent Hot-Reloading:** When you change a workspace transition, Umbriel only reloads `umbriel-effect-workspace.toml` while your active cursor and window shaders remain untouched.
3. **Clean Lifecycle Control:** Clearing one slot writes an empty header to that specific file, instantly resetting that behavior while keeping other effects active.

### 2. Copying Contents Instead of Using `[include]`

In Umbriel community shaders (`~/.config/umbriel/shaders/community/`), each directory contains `shader.glsl`, `effect.toml`, and an activation example `config.toml`.

Because Umbriel resolves shader paths relative to `effect.toml`, `config.toml` files are **activation snippets meant to be merged, not included**. When you apply an effect, the plugin reads that effect's `config.toml` and writes its exact contents into the appropriate slot file:

```toml
# Umbriel Community Effects - Workspace slot
# Active Effect: animation/workspace-burn
# Applied automatically by Noctalia UmbrielFXctl

[include]
files = ["shaders/community/animation/workspace-burn/effect.toml"]

[animation]
enabled = true

[animation.workspaces]
enabled = true
style = "reveal"
effect = "workspace-burn"
duration_ms = 1000
curve = "linear"
```

Umbriel detects the file modification live and compiles the shader immediately without compositor disturbance.

---

## Directory Structure

```text
umbrielfxctl/
├── bin/
│   └── umbriel-effects.py      # Python CLI backend managing 6 independent slot files
├── plugin.toml                 # Noctalia plugin manifest, settings, and entries
├── service.luau                # Background service coordinating multi-slot state
├── panel.luau                  # Declarative UI panel with 6 tabs and tooltip actions
├── widget.luau                 # Bar widget displaying active FX summary
├── shortcut.luau               # Control Center toggle tile
└── README.md                   # This documentation
```

---

## Commands Reference

### Noctalia Plugin Commands & IPC

You can manage Umbriel effects and configuration directly from terminal commands, fish functions, or compositor keybindings:

```bash
# Setup or re-setup all 6 slot files and register them in config.toml
noctalia msg plugin SoM/umbrielfxctl:service all setup

# Remove all generated config files and clear [include.optional] lines from config.toml
noctalia msg plugin SoM/umbrielfxctl:service all remove-config

# Clear active effects across all 6 slots
noctalia msg plugin SoM/umbrielfxctl:service all clear

# Clear a specific slot (e.g. cursor, workspace, in-out, move, border, misc)
noctalia msg plugin SoM/umbrielfxctl:service all clear cursor

# Apply an effect via IPC
noctalia msg plugin SoM/umbrielfxctl:service all apply animation/workspace-burn

# Toggle the effects panel
noctalia msg panel-toggle SoM/umbrielfxctl:panel
```

---

## CLI Helper Reference

You can also inspect and manipulate the 6 slots via the Python backend:

```bash
# Remove all generated effect files and clear [include.optional] entries from config.toml
python3 bin/umbriel-effects.py clean

# Setup all 6 slot files and register them in config.toml
python3 bin/umbriel-effects.py setup

# List all available shaders categorized with slot mappings and relative paths
python3 bin/umbriel-effects.py list

# View active status across all 6 slots
python3 bin/umbriel-effects.py status

# Apply a workspace transition
python3 bin/umbriel-effects.py apply animation/workspace-burn

# Apply an in-out window animation
python3 bin/umbriel-effects.py apply animation/vhs

# Apply a misc window shader
python3 bin/umbriel-effects.py apply window/crt

# Clear a specific slot (workspace, in-out, move, misc, border, cursor)
python3 bin/umbriel-effects.py clear cursor

# Clear all 6 slots
python3 bin/umbriel-effects.py clear all
```

Verify with Umbriel:
```bash
umbriel config validate
umbriel effects
```
