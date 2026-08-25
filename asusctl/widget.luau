local data = noctalia.state.get("asusctl_data") or {
  active_profile = "Unknown",
  ac_profile = "Unknown",
  battery_profile = "Unknown",
  charge_limit = "Unknown"
}


local function profileGlyph(profile)
  local glyphs = data.glyphs or { quiet = "windmill-off", balanced = "windmill", performance = "windmill-filled" }
  if profile == "Quiet" then return glyphs.quiet
  elseif profile == "Balanced" then return glyphs.balanced
  elseif profile == "Performance" then return glyphs.performance
  else return glyphs.performance end
end

local function render()
  local display_style = noctalia.getConfig("display_style") or "both"
  local text_color = noctalia.getConfig("color") or "on_surface"
  local icon_color = noctalia.getConfig("icon_color") or "on_surface"

  pcall(function() barWidget.setGlyph("") end)
  pcall(function() barWidget.setText("") end)

  local children = {}
  
  if display_style == "both" or display_style == "icon" then
    table.insert(children, ui.glyph({ name = profileGlyph(data.active_profile), size = 14, color = icon_color }))
  end
  
  if display_style == "both" or display_style == "text" then
    table.insert(children, ui.label({ text = data.active_profile, fontSize = 13, color = text_color }))
  end
  
  barWidget.render(ui.row({ gap = 5, align = "center" }, children))
  
  -- API 26 Tooltip
  local tooltip_rows = {
    { key = "Active Profile", value = data.active_profile },
    { key = "AC Profile", value = data.ac_profile },
    { key = "Battery Profile", value = data.battery_profile },
    { key = "Charge Limit", value = tostring(data.charge_limit) }
  }
  
  barWidget.setTooltip(tooltip_rows)
end

function onClick()
  noctalia.togglePanel("SoM/asusctl:panel")
end



noctalia.state.watch("asusctl_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

render()
