local scale = noctalia.getSetting("shell.corner_radius_scale")
local radius = 10 * scale

local data = noctalia.state.get("powermon_data") or {
  battery = 0, cpu = 0, gpu = 0, npu = 0, battery_percent = 0, battery_time_minutes = 0, history = {battery={}, cpu={}, gpu={}, npu={}, battery_percent={}, battery_time={}}
}

noctalia.state.watch("powermon_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

local function normalize(history, max_val)
  if max_val <= 0 then max_val = 1 end
  local normalized = {}
  for i, v in ipairs(history) do
    table.insert(normalized, math.min(1, (v or 0) / max_val))
  end
  return normalized
end

local function get_max(history)
  local max_val = 0
  for _, v in ipairs(history) do
    if (v or 0) > max_val then max_val = v end
  end
  return math.max(10, max_val * 1.2)
end

function render()
  local panel_style = noctalia.getConfig("panel_style") or "classic"
  
  local show_system = noctalia.getConfig("show_system") ~= false
  local show_cpu = noctalia.getConfig("show_cpu") ~= false
  local show_gpu = noctalia.getConfig("show_gpu") ~= false
  local show_dgpu = noctalia.getConfig("show_dgpu") ~= false
  local show_npu = noctalia.getConfig("show_npu") ~= false
  local show_battery_time = noctalia.getConfig("show_battery_time") ~= false
  local show_battery_percent = noctalia.getConfig("show_battery_percent") ~= false



  local content_node

  if panel_style == "native" then
    local cards = {}
    
    local function add_native_card(title, val_str, hist, color, fixed_max)
      local max_val = fixed_max or get_max(hist)
      local norm = normalize(hist, max_val)
      if #norm == 0 then norm = {0} end
      
      local tm = noctalia.getSetting("shell.panels.transparency_mode") or "glass"
      local graph_op = 0
      if tm == "glass" then
        graph_op = 0.15
      elseif tm == "soft" then
        graph_op = 0.95
      end
      
      local card_fill = "surface_variant"
      if tm == "glass" then
        card_fill = "surface_variant/0.6"
      elseif tm == "soft" then
        card_fill = "surface_variant"
      end

      local graph = ui.graph({
        values = norm,
        color = color,
        lineWidth = 2,
        fillOpacity = graph_op,
        height = 50
      })
      
      local has_card_borders = noctalia.getSetting("shell.card_borders")
      local b_width = (has_card_borders == false) and 0 or 1
      local b_color = (has_card_borders == false) and "transparent" or "outline"

      table.insert(cards, ui.column({
        gap = 10,
        padding = 10,
        fill = card_fill,
        radius = radius,
        border = b_color,
        borderWidth = b_width,
        flexGrow = 1
      }, {
        ui.label({ text = title, fontWeight = "bold", fontSize = 16 }),
        ui.column({ flexGrow = 1, justify = "end" }, { graph }),
        ui.row({ justify = "center", align = "center" }, {
          ui.label({ text = val_str, fontSize = 13, color = "on_surface_variant" })
        })
      }))
    end

    if show_cpu then add_native_card("CPU", string.format("%.1f W", data.cpu), data.history.cpu or {}, "secondary") end
    if show_gpu then add_native_card("GPU", string.format("%.1f W", data.gpu), data.history.gpu or {}, "tertiary") end
    if show_dgpu then add_native_card("dGPU", string.format("%.1f W", data.dgpu), data.history.dgpu or {}, "tertiary") end
    if show_npu then add_native_card("NPU", string.format("%.1f W", data.npu), data.history.npu or {}, "error") end
    
    if show_system then 
      local sys_val = string.format("%.1f W", data.battery)
      if show_battery_percent and data.battery_percent then
        sys_val = sys_val .. string.format("  ·  %d%%", data.battery_percent)
      end
      if show_battery_time and data.battery_time_val and data.battery_time_val ~= "" then
        sys_val = sys_val .. string.format("  ·  %s", data.battery_time_val)
      end
      add_native_card("System (Battery)", sys_val, data.history.battery or {}, "primary") 
    end

    local rows = {}
    for i = 1, #cards, 2 do
      local row_children = { cards[i] }
      if cards[i+1] then table.insert(row_children, cards[i+1]) end
      table.insert(rows, ui.row({ gap = 15 }, row_children))
    end
    
    local header = ui.row({ align = "center", justify = "space_between", padding = { bottom = 5 } }, {
      ui.label({ text = "Power Monitor", fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.button({ variant = "tonal", glyph = "x", onClick = function() panel.close() end })
    })

    content_node = ui.column({ padding = 5, flexGrow = 1 }, {
      header,
      ui.scroll({ gap = 15, flexGrow = 1 }, rows)
    })

  else
    -- Classic style
    local children = {}
    table.insert(children, ui.label({ text = "Power Monitor", fontWeight = "bold", fontSize = 16 }))
    table.insert(children, ui.separator({ spacing = 10 }))
    
    local function add_classic_graph(title, val_str, hist, color, fixed_max)
      local max_val = fixed_max or get_max(hist)
      local norm = normalize(hist, max_val)
      if #norm == 0 then norm = {0} end
      
      local header = ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = title, fontWeight = "bold" }),
        ui.label({ text = val_str })
      })
      local graph = ui.graph({
        values = norm,
        color = color,
        lineWidth = 2,
        fillOpacity = 0.2,
        height = 60
      })
      
      table.insert(children, ui.column({ gap = 10 }, { graph, header }))
    end
    
    if show_cpu then add_classic_graph("CPU", string.format("%.1f W", data.cpu), data.history.cpu or {}, "secondary") end
    if show_gpu then add_classic_graph("GPU", string.format("%.1f W", data.gpu), data.history.gpu or {}, "tertiary") end
    if show_dgpu then add_classic_graph("dGPU", string.format("%.1f W", data.dgpu), data.history.dgpu or {}, "tertiary") end
    if show_npu then add_classic_graph("NPU", string.format("%.1f W", data.npu), data.history.npu or {}, "error") end
    
    if show_system then 
      local sys_val = string.format("%.1f W", data.battery)
      if show_battery_percent and data.battery_percent then
        sys_val = sys_val .. string.format("  ·  %d%%", data.battery_percent)
      end
      if show_battery_time and data.battery_time_val and data.battery_time_val ~= "" then
        sys_val = sys_val .. string.format("  ·  %s", data.battery_time_val)
      end
      add_classic_graph("System (Battery)", sys_val, data.history.battery or {}, "primary") 
    end

    content_node = ui.scroll({ gap = 25, padding = 15, flexGrow = 1 }, children)
  end

  panel.render(ui.column({
    flexGrow = 1,
    radius = radius,
    onRightClick = function() panel.openContextMenu() end
  }, { content_node }))
end

render()
