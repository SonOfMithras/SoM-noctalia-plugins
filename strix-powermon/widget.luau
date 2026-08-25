local show_system = noctalia.getConfig("show_system") ~= false
local show_cpu = noctalia.getConfig("show_cpu") ~= false
local show_gpu = noctalia.getConfig("show_gpu") ~= false
local show_dgpu = noctalia.getConfig("show_dgpu") ~= false
local show_npu = noctalia.getConfig("show_npu") ~= false
local show_battery_time = noctalia.getConfig("show_battery_time") ~= false
local show_battery_percent = noctalia.getConfig("show_battery_percent") ~= false
local show_icon = noctalia.getConfig("show_icon") ~= false
local show_text = noctalia.getConfig("show_text") ~= false
local icon_name = noctalia.getConfig("icon_name") or "battery-charging"
local display_stat = noctalia.getConfig("display_stat") or "auto"

local data = {
  battery = 0,
  cpu = 0,
  gpu = 0,
  dgpu = 0,
  npu = 0,
  battery_time_label = nil,
  battery_time_val = nil,
  battery_percent = 0,
  battery_time_minutes = 0
}

local PANEL_ID = "SoM/strix-powermon:panel"

local function render()
  local text = ""
  if display_stat == "battery_percent" then
    text = string.format("%d%%", data.battery_percent)
  elseif display_stat == "battery_time" then
    text = data.battery_time_val or "N/A"
  elseif display_stat == "cpu" then
    text = string.format("%.1f W", data.cpu)
  elseif display_stat == "gpu" then
    text = string.format("%.1f W", data.gpu)
  elseif display_stat == "dgpu" then
    text = string.format("%.1f W", data.dgpu)
  elseif display_stat == "npu" then
    text = string.format("%.1f W", data.npu)
  elseif display_stat == "battery" then
    text = string.format("%.1f W", data.battery)
  else
    local display_power = data.battery > 0 and data.battery or data.cpu
    text = string.format("%.1f W", display_power)
  end

  local text_color = noctalia.getConfig("color") or "on_surface"
  local icon_color = noctalia.getConfig("icon_color") or "on_surface"


  local children = {}
  if show_icon and icon_name ~= "" then
    local final_icon = icon_name
    if icon_name == "battery-charging" and data.battery_percent then
      if data.battery_percent <= 25 then
        final_icon = "battery-1"
      elseif data.battery_percent <= 50 then
        final_icon = "battery-2"
      elseif data.battery_percent <= 75 then
        final_icon = "battery-3"
      else
        final_icon = "battery-4"
      end
    end
    table.insert(children, ui.glyph({ name = final_icon, size = 14, color = icon_color }))
  end
  if show_text and text ~= "" then
    table.insert(children, ui.label({ text = text, fontSize = 13, color = text_color }))
  end
  
  barWidget.render(ui.row({ gap = 5, align = "center" }, children))
  
  -- API 26 Tooltip
  local tooltip_rows = {}
  local function addLine(label, value)
    table.insert(tooltip_rows, { key = label, value = value })
  end
  
  if show_system then addLine("System (Battery)", string.format("%.1f W", data.battery)) end
  if show_cpu then addLine("CPU", string.format("%.1f W", data.cpu)) end
  if show_gpu then addLine("GPU", string.format("%.1f W", data.gpu)) end
  if show_dgpu then addLine("dGPU", string.format("%.1f W", data.dgpu)) end
  if show_npu then addLine("NPU", string.format("%.1f W", data.npu)) end
  if show_battery_percent then addLine("Battery Percent", string.format("%d%%", data.battery_percent)) end
  
  if show_battery_time and data.battery_time_label and data.battery_time_val then
    addLine(data.battery_time_label, data.battery_time_val)
  end
  
  barWidget.setTooltip(tooltip_rows)
end


noctalia.state.watch("powermon_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

-- Initial render
data = noctalia.state.get("powermon_data") or data
render()
