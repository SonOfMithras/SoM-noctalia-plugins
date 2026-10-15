-- ============================================================================
-- UmbrielFXctl - Panel Entry
-- ============================================================================
-- Principles:
-- 1. Multi-Slot Architecture:
--    Supports 6 independent Umbriel effect include files:
--    - umbriel-effect-workspace.toml (Workspace transitions)
--    - umbriel-effect-in-out.toml     (Window opening/closing lifecycle)
--    - umbriel-effect-move.toml       (Window movement & resize deformation)
--    - umbriel-effect-misc.toml       (Misc window shaders, overlays & screen FX)
--    - umbriel-effect-border.toml     (Focused window border shaders)
--    - umbriel-effect-cursor.toml     (Pointer trails and cursor FX)
--    Enables simultaneous activation of one effect per type!
-- 2. Contextual Tooltips & File Manager Integration:
--    Tooltips display the relative path from ~/.config/umbriel/.
--    Right-clicking any card, button, or thumbnail opens that effect's folder
--    in the user's default file manager via xdg-open.
-- ============================================================================

local scale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
local radius = 10 * scale

local default_tab = noctalia.getConfig("default_tab") or "workspace"
local current_slot = default_tab
local show_previews = noctalia.getConfig("show_previews")
if show_previews == nil then show_previews = true end

local data = noctalia.state.get("umbriel_effects_data") or {
  is_configured = true,
  slots = {},
  active_effects = {},
  effect_names = {},
  effects = {}
}

-- Open directory in user's default file manager
local function openFolder(folder_path)
  if folder_path and folder_path ~= "" then
    noctalia.runAsync({"xdg-open", folder_path}, function() end)
  end
end

-- Check if an effect is active in its slot
local function isEffectActive(effect)
  if data.slots and data.slots[effect.slot] then
    local slot_info = data.slots[effect.slot]
    if slot_info.active_id == effect.id or slot_info.active_name == effect.name then
      return true
    end
  end
  return false
end

-- Get active display name for a specific slot
local function getSlotActiveName(slot)
  if data.slots and data.slots[slot] and data.slots[slot].is_active then
    local name = data.slots[slot].active_name or data.slots[slot].active_id
    if name then
      return (name:gsub("-", " "):gsub("^%l", string.upper))
    end
  end
  return nil
end

-- Dispatch apply command
local function applyEffect(effect)
  if not data.slots then data.slots = {} end
  data.slots[effect.slot] = {
    active_id = effect.id,
    active_name = effect.name,
    is_active = true
  }
  render()

  noctalia.state.set("umbriel_effects_cmd", {
    action = "apply",
    effect_id = effect.id,
    slot = effect.slot,
    timestamp = os.time()
  })
end

-- Dispatch clear slot command
local function clearSlot(slot)
  if data.slots and data.slots[slot] then
    data.slots[slot].is_active = false
    data.slots[slot].active_id = nil
    data.slots[slot].active_name = nil
  end
  render()

  noctalia.state.set("umbriel_effects_cmd", {
    action = "clear",
    slot = slot,
    timestamp = os.time()
  })
end

-- Dispatch clear all command
local function clearAll()
  if data.slots then
    for s, _ in pairs(data.slots) do
      data.slots[s].is_active = false
      data.slots[s].active_id = nil
      data.slots[s].active_name = nil
    end
  end
  render()

  noctalia.state.set("umbriel_effects_cmd", {
    action = "clear",
    slot = "all",
    timestamp = os.time()
  })
end

-- Dispatch refresh command
local function refreshEffects()
  noctalia.state.set("umbriel_effects_cmd", {
    action = "refresh",
    timestamp = os.time()
  })
end

-- Dispatch remove config files and clear includes
local function removeConfigs()
  if data.slots then
    for s, _ in pairs(data.slots) do
      data.slots[s].is_active = false
      data.slots[s].active_id = nil
      data.slots[s].active_name = nil
      data.slots[s].exists = false
    end
  end
  data.active_effects = {}
  data.effect_names = {}
  render()

  noctalia.state.set("umbriel_effects_cmd", {
    action = "remove-configs",
    timestamp = os.time()
  })
end

-- Dispatch setup / resetup config files and register includes
local function setupConfigs()
  noctalia.state.set("umbriel_effects_cmd", {
    action = "setup",
    timestamp = os.time()
  })
end

-- Plugin IPC command entry (e.g. noctalia msg plugin SoM/umbrielfxctl:panel all setup)
function onIpc(event, payload)
  if event == "setup" or event == "resetup" then
    setupConfigs()
  elseif event == "remove-config" or event == "remove-configs" or event == "clean" or event == "uninstall" or event == "purge" then
    removeConfigs()
  end
end

-- Tab button helper with active indicator
local function tabButton(slot_id, label, glyph)
  local is_selected = (current_slot == slot_id)
  local slot_active = (getSlotActiveName(slot_id) ~= nil)

  local display_text = label
  if slot_active then
    display_text = label .. " •"
  end

  return ui.button({
    key = "tab-" .. slot_id .. "-" .. (is_selected and "on" or "off"),
    text = display_text,
    glyph = glyph,
    variant = is_selected and "primary" or "ghost",
    controlSize = "sm",
    tooltip = slot_active and (label .. " (Active: " .. getSlotActiveName(slot_id) .. ")") or (label .. " effects"),
    onClick = function()
      current_slot = slot_id
      render()
    end
  })
end

-- Filter effects matching the current active slot
local function getSlotEffects()
  local list = {}
  if not data.effects then return list end

  for _, eff in ipairs(data.effects) do
    if eff.slot == current_slot then
      table.insert(list, eff)
    end
  end
  return list
end

function render()
  local has_card_borders = noctalia.getSetting("shell.card_borders")
  local b_width = (has_card_borders == false) and 0 or 1
  local b_color = (has_card_borders == false) and "transparent" or "outline"

  local tm = noctalia.getSetting("shell.panels.transparency_mode") or "glass"
  local card_fill = "surface_variant"
  if tm == "glass" then
    card_fill = "surface_variant/0.6"
  end

  local slot_active_name = getSlotActiveName(current_slot)
  local total_active_count = 0
  if data.slots then
    for _, s in pairs(data.slots) do
      if s.is_active then total_active_count = total_active_count + 1 end
    end
  end

  -- 1. Header Row
  local header = ui.row({
    align = "center",
    justify = "space_between",
    paddingV = 4
  }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = "sparkles", size = 22, color = "primary" }),
      ui.column({ gap = 2 }, {
        ui.label({ text = "UmbrielFXctl", fontWeight = "bold", fontSize = 16 }),
        ui.label({
          text = string.format("%d of 6 slots active", total_active_count),
          fontSize = 12,
          color = total_active_count > 0 and "primary" or "on_surface_variant"
        })
      })
    }),
    ui.row({ gap = 6, align = "center" }, {
      total_active_count > 0 and ui.button({
        glyph = "trash",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Clear all 6 slots",
        onClick = clearAll
      }) or ui.spacer(),
      ui.button({
        glyph = "refresh",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Re-scan shader library",
        onClick = refreshEffects
      }),
      ui.button({
        glyph = "file-plus",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Setup / Recreate config files & register includes",
        onClick = setupConfigs
      }),
      ui.button({
        glyph = "file-x",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Remove config files & clear includes",
        onClick = removeConfigs
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Close panel",
        onClick = function() panel.close() end
      })
    })
  })

  -- 2. 6 Slot Navigation Tabs
  local tabs = ui.row({
    gap = 4,
    align = "center",
    justify = "space_between",
    paddingV = 2
  }, {
    tabButton("workspace", "Workspace", "carousel-horizontal"),
    tabButton("in-out", "In/Out", "window"),
    tabButton("move", "Move", "arrows-move"),
    tabButton("border", "Border", "border-all"),
    tabButton("cursor", "Cursor", "pointer"),
    tabButton("misc", "Misc FX", "sparkles")
  })

  -- 3. Slot Status Banner
  local slot_file = "umbriel-effect-" .. current_slot .. ".toml"
  local slot_info = data.slots and data.slots[current_slot]
  local file_exists = slot_info and slot_info.exists
  local slot_subtitle = (file_exists == false) and ("File " .. slot_file .. " not present (creates on apply)") or ("Included via " .. slot_file)
  local slot_title
  if current_slot == "in-out" then
    slot_title = "In/Out"
  elseif current_slot == "misc" then
    slot_title = "Misc FX"
  else
    slot_title = current_slot:gsub("-", " "):gsub("^%l", string.upper)
  end
  local status_banner = ui.row({
    align = "center",
    justify = "space_between",
    padding = 10,
    fill = card_fill,
    border = b_color,
    borderWidth = b_width,
    radius = radius
  }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({
        name = slot_active_name and "check-circle" or "circle-dashed",
        size = 18,
        color = slot_active_name and "primary" or "on_surface_variant"
      }),
      ui.column({ gap = 2 }, {
        ui.label({
          text = slot_active_name and (slot_title .. ": " .. slot_active_name) or ("No " .. slot_title .. " effect active"),
          fontWeight = "medium",
          fontSize = 13,
          color = slot_active_name and "primary" or "on_surface"
        }),
        ui.label({
          text = slot_subtitle,
          fontSize = 11,
          color = "on_surface_variant"
        })
      })
    }),
    (slot_active_name and ui.button({
      glyph = "trash",
      variant = "destructive",
      controlSize = "sm",
      tooltip = "Clear " .. slot_title .. " effect",
      onClick = function() clearSlot(current_slot) end
    })) or (file_exists == false and ui.button({
      glyph = "file-plus",
      text = "Setup",
      variant = "tonal",
      controlSize = "sm",
      tooltip = "Recreate all 6 slot files and register in config.toml",
      onClick = setupConfigs
    })) or ui.spacer()
  })

  -- 4. Effect Cards for Current Slot
  local slot_effects = getSlotEffects()
  local effect_cards = {}

  if #slot_effects == 0 then
    table.insert(effect_cards, ui.column({
      align = "center",
      justify = "center",
      padding = 35,
      gap = 10
    }, {
      ui.glyph({ name = "movie-off", size = 32, color = "on_surface_variant" }),
      ui.label({ text = "No shaders found for " .. slot_title, color = "on_surface_variant", fontSize = 13 })
    }))
  else
    for _, eff in ipairs(slot_effects) do
      local is_active = isEffectActive(eff)
      local rel_path = eff.rel_path or ("shaders/community/" .. eff.id)

      -- Tooltips showing title, relative path from umbriel root, and right-click hint
      local card_tooltip = eff.title .. "\nPath: " .. rel_path .. "\nRight-click: open in file manager"
      local btn_tooltip = (is_active and ("Active in " .. eff.slot .. " (Click to remove)\n") or ("Apply " .. eff.title .. "\n"))
        .. "Path: " .. rel_path .. "\nRight-click: open in file manager"

      local left_preview
      if show_previews and eff.has_preview and eff.preview_path ~= "" then
        left_preview = ui.image({
          path = eff.preview_path,
          width = 96,
          height = 60,
          radius = 6,
          fit = "cover",
          border = "outline",
          borderWidth = 1,
          tooltip = card_tooltip,
          onRightClick = function() openFolder(eff.path) end
        })
      else
        local icon_name = "sparkles"
        if eff.slot == "workspace" then icon_name = "carousel-horizontal"
        elseif eff.slot == "move" then icon_name = "arrows-move"
        elseif eff.slot == "cursor" then icon_name = "pointer"
        elseif eff.slot == "border" then icon_name = "border-all"
        elseif eff.slot == "in-out" then icon_name = "window"
        else icon_name = "sparkles" end

        left_preview = ui.column({
          width = 96,
          height = 60,
          align = "center",
          justify = "center",
          fill = "surface",
          radius = 6,
          border = "outline",
          borderWidth = 1,
          tooltip = card_tooltip,
          onRightClick = function() openFolder(eff.path) end
        }, {
          ui.glyph({ name = icon_name, size = 22, color = "primary" })
        })
      end

      -- Icon-only button with full path tooltip and right-click open action
      local action_btn = ui.button({
        key = "btn-" .. eff.id .. "-" .. (is_active and "active" or "apply"),
        glyph = is_active and "check" or "player-play",
        variant = is_active and "primary" or "tonal",
        controlSize = "sm",
        tooltip = btn_tooltip,
        onClick = function()
          if is_active then
            clearSlot(eff.slot)
          else
            applyEffect(eff)
          end
        end,
        onRightClick = function()
          openFolder(eff.path)
        end
      })

      local card = ui.row({
        key = "card-" .. eff.id,
        gap = 12,
        align = "center",
        padding = 10,
        fill = is_active and "primary/0.12" or card_fill,
        border = is_active and "primary" or b_color,
        borderWidth = is_active and 1.5 or b_width,
        radius = radius,
        tooltip = card_tooltip,
        onRightClick = function()
          openFolder(eff.path)
        end
      }, {
        left_preview,
        ui.column({ gap = 3, flexGrow = 1 }, {
          ui.row({ gap = 8, align = "center" }, {
            ui.label({ text = eff.title, fontWeight = "bold", fontSize = 13 }),
            ui.label({ text = eff.name, fontSize = 10, color = "on_surface_variant" })
          }),
          ui.label({
            text = eff.description,
            fontSize = 11,
            color = "on_surface_variant",
            maxLines = 2
          })
        }),
        action_btn
      })

      table.insert(effect_cards, card)
    end
  end

  -- 5. Bottom Info Note
  local footer_note = ui.row({
    align = "center",
    justify = "center",
    padding = 6
  }, {
    ui.glyph({ name = "info-circle", size = 13, color = "on_surface_variant" }),
    ui.spacer({ width = 6 }),
    ui.label({
      text = "Right-click any card to open folder in Dolphin. Live hot-reload on click.",
      fontSize = 11,
      color = "on_surface_variant"
    })
  })

  -- Main Container
  local content = ui.column({
    gap = 9,
    flexGrow = 1
  }, {
    header,
    tabs,
    status_banner,
    ui.scroll({
      key = "slot-effects-scroll",
      gap = 8,
      flexGrow = 1
    }, effect_cards),
    ui.separator({ spacing = 2 }),
    footer_note
  })

  panel.render(ui.column({
    padding = 14,
    flexGrow = 1,
    radius = radius,
    onRightClick = function() panel.openContextMenu() end
  }, { content }))
end

-- Watch state updates from the service
noctalia.state.watch("umbriel_effects_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

-- Initial render
render()
