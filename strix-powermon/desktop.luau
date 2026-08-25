local scale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
local radius = 8 * scale
local data = noctalia.state.get("powermon_data") or {
  battery = 0, cpu = 0, gpu = 0, dgpu = 0, npu = 0, battery_percent = 0, battery_time_minutes = 0
}

noctalia.state.watch("powermon_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

function render()

  local show_icon = noctalia.getConfig("show_title_icon") ~= false
  local show_battery_percent = noctalia.getConfig("show_battery_percent") ~= false
  local show_cpu = noctalia.getConfig("show_cpu") ~= false
  local show_gpu = noctalia.getConfig("show_gpu") ~= false
  local show_dgpu = noctalia.getConfig("show_dgpu") ~= false
  local show_system = noctalia.getConfig("show_system") ~= false

  local title_color = noctalia.getConfig("title_color") or "on_surface"
  local children = {}
  
  if show_icon or show_battery_percent then
    local header_children = {}
    if show_icon then
      local bat_icon = "battery-4"
      if data.battery_percent then
        if data.battery_percent <= 25 then
          bat_icon = "battery-1"
        elseif data.battery_percent <= 50 then
          bat_icon = "battery-2"
        elseif data.battery_percent <= 75 then
          bat_icon = "battery-3"
        end
      end
      table.insert(header_children, ui.glyph({ name = bat_icon, size = 32, color = "primary" }))
    end
    if show_battery_percent then
      table.insert(header_children, ui.label({ text = string.format("%d%%", data.battery_percent), fontSize = 32, fontWeight = "bold", color = title_color }))
    end
    table.insert(children, ui.row({ gap = 10, align = "center" }, header_children))
  end
  
  local function makeRow(glyph_key, label_prefix, val_str, color_key, hide_text_key)
    local g = noctalia.getConfig(glyph_key)
    local c = noctalia.getConfig(color_key) or "on_surface_variant"
    local hide_text = noctalia.getConfig(hide_text_key) == true
    local row_children = {}
    if g and g ~= "" then
      table.insert(row_children, ui.glyph({ name = g, size = 16, color = c }))
    end
    
    local final_text = hide_text and val_str or (label_prefix .. val_str)
    table.insert(row_children, ui.label({ text = final_text, fontSize = 16, color = c }))
    
    if #row_children == 1 then return row_children[1] end
    if #row_children == 0 then return nil end
    return ui.row({ gap = 8, align = "center" }, row_children)
  end

  if show_cpu then
    local r = makeRow("cpu_glyph", "CPU: ", string.format("%.1f W", data.cpu), "cpu_color", "hide_cpu_text")
    if r then table.insert(children, r) end
  end
  if show_gpu then
    local r = makeRow("gpu_glyph", "GPU: ", string.format("%.1f W", data.gpu), "gpu_color", "hide_gpu_text")
    if r then table.insert(children, r) end
  end
  if show_dgpu then
    local r = makeRow("dgpu_glyph", "dGPU: ", string.format("%.1f W", data.dgpu), "dgpu_color", "hide_dgpu_text")
    if r then table.insert(children, r) end
  end
  if show_system then
    local r = makeRow("sys_glyph", "SYS: ", string.format("%.1f W", data.battery), "sys_color", "hide_sys_text")
    if r then table.insert(children, r) end
  end

  local content = ui.column({ 
    gap = 10, align = "center",
  }, children)

  if desktopWidget and desktopWidget.connector then
    noctalia.setWallpaperMask(desktopWidget.connector, true)
  end

  if desktopWidget and desktopWidget.render then
    desktopWidget.render(content)
  end
end

render()
