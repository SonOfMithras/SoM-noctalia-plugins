-- ============================================================================
-- UmbrielFXctl - Bar Widget Entry
-- ============================================================================
-- Principles:
-- 1. Multi-Slot Status Bar Display:
--    Summarizes active effects across the 6 independent slots.
-- 2. Interactive Trigger:
--    Clicking the widget opens the attached effects selection panel.
-- ============================================================================

local data = noctalia.state.get("umbriel_effects_data") or {
  slots = {},
  active_effects = {},
  effect_names = {}
}

local function getActiveSummary()
  local active_list = {}
  if data.slots then
    for slot, info in pairs(data.slots) do
      if info.is_active and info.active_name then
        local formatted = (info.active_name:gsub("-", " "):gsub("^%l", string.upper))
        table.insert(active_list, formatted)
      end
    end
  end

  local count = #active_list
  if count == 0 then
    return "Umbriel FX", "Umbriel Effects (None active)", false
  elseif count == 1 then
    return active_list[1], "Active: " .. active_list[1], true
  else
    local tooltip = "Active: " .. table.concat(active_list, ", ")
    return string.format("%d FX", count), tooltip, true
  end
end

function render()
  local display_style = noctalia.getConfig("display_style") or "both"
  local text_color = noctalia.getConfig("color") or "on_surface"
  local icon_color = noctalia.getConfig("icon_color") or "primary"

  local label_text, tooltip_text, has_active = getActiveSummary()

  local children = {}

  if display_style == "both" or display_style == "icon" then
    table.insert(children, ui.glyph({
      name = has_active and "sparkles" or "wand",
      size = 14,
      color = has_active and icon_color or "on_surface_variant"
    }))
  end

  if display_style == "both" or display_style == "text" then
    table.insert(children, ui.label({
      text = label_text,
      fontSize = 13,
      color = has_active and text_color or "on_surface_variant"
    }))
  end

  barWidget.render(ui.row({
    gap = 6,
    align = "center",
    tooltip = tooltip_text
  }, children))
end

function onClick()
  noctalia.togglePanel("SoM/umbrielfxctl:panel")
end

noctalia.state.watch("umbriel_effects_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

render()
