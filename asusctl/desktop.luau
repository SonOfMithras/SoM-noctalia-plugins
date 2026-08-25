local scale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
local radius = 10 * scale
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
  else return "circle" end
end

function render()
  local bg_color = noctalia.getConfig("bg_color") or "surface"
  local bg_opacity = noctalia.getConfig("bg_opacity") or 0
  local fill_val = nil
  if bg_opacity == 100 then
    fill_val = bg_color
  elseif bg_opacity > 0 then
    fill_val = bg_color .. string.format("/%.2f", bg_opacity / 100)
  end

  local show_ac_batt = noctalia.getConfig("show_ac_batt_profiles")
  if show_ac_batt == nil then show_ac_batt = true end

  local text_color = noctalia.getConfig("text_color") or "on_surface"
  local glyph_color = noctalia.getConfig("glyph_color") or "primary"

  local children = {
    ui.glyph({ name = profileGlyph(data.active_profile), size = 32, color = glyph_color }),
    ui.label({ text = data.active_profile, fontSize = 24, fontWeight = "bold", color = text_color })
  }

  if show_ac_batt then
    table.insert(children, ui.label({ text = "AC: " .. data.ac_profile, fontSize = 14, color = text_color }))
    table.insert(children, ui.label({ text = "BAT: " .. data.battery_profile, fontSize = 14, color = text_color }))
  end

  table.insert(children, ui.label({ text = "Limit: " .. data.charge_limit, fontSize = 14, color = text_color }))

  local content = ui.column({
    gap = 10, padding = 20, align = "center",
    fill = fill_val, border = "border", borderWidth = 1, radius = radius
  }, children)

  if desktopWidget and desktopWidget.connector then
    local wp = noctalia.wallpaperPath(desktopWidget.connector)
    if wp then
      noctalia.setWallpaperMask(desktopWidget.connector, true)
    end
  end

  if desktopWidget and desktopWidget.render then
    desktopWidget.render(content)
  end
end

noctalia.state.watch("asusctl_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

render()
