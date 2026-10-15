-- ============================================================================
-- UmbrielFXctl - Control Center Shortcut Entry
-- ============================================================================
-- Principles:
-- 1. Control Center Tile:
--    Provides a quick-access toggle tile in Noctalia's Control Center.
-- 2. Multi-Slot Visual State:
--    Illuminates whenever any of the 6 effect slots is active.
-- ============================================================================

local function applyStatus(data)
  local current_data = type(data) == "table" and data or nil

  local active_count = 0
  local first_name = nil

  if current_data and current_data.slots then
    for _, info in pairs(current_data.slots) do
      if info.is_active and info.active_name then
        active_count = active_count + 1
        if not first_name then
          first_name = info.active_name:gsub("-", " "):gsub("^%l", string.upper)
        end
      end
    end
  end

  local is_active = (active_count > 0)
  local label = "Shaders"
  if active_count == 1 then
    label = first_name
  elseif active_count > 1 then
    label = string.format("%d FX", active_count)
  end

  shortcut.setLabel(label)
  shortcut.setIcon(is_active and "sparkles" or "wand", "sparkles")
  shortcut.setActive(is_active)
  shortcut.setEnabled(true)
end

applyStatus(noctalia.state.get("umbriel_effects_data"))
noctalia.state.watch("umbriel_effects_data", applyStatus)

function onClick()
  noctalia.togglePanel("SoM/umbrielfxctl:panel")
end
