local scale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
local radius = 10 * scale

local data = noctalia.state.get("asusctl_data") or {
  active_profile = "Unknown",
  ac_profile = "Unknown",
  battery_profile = "Unknown",
  charge_limit = "Unknown"
}


local function setProfile(mode, profile)
  local cmd = "asusctl profile set "
  if mode == "ac" then
    cmd = cmd .. "-a "
  elseif mode == "battery" then
    cmd = cmd .. "-b "
  end
  cmd = cmd .. profile
  
  -- Optimistically update UI
  if mode == "active" then
    data.active_profile = profile
  elseif mode == "ac" then
    data.ac_profile = profile
  elseif mode == "battery" then
    data.battery_profile = profile
  end
  noctalia.state.set("asusctl_data", data)
  render()
  
  noctalia.runAsync(cmd, function() end)
end

local function setLimit(val)
  -- Optimistically update UI
  data.charge_limit = tostring(val) .. "%"
  noctalia.state.set("asusctl_data", data)
  render()
  noctalia.runAsync("asusctl battery limit " .. tostring(val), function() end)
end

local function oneshot()
  noctalia.runAsync("asusctl battery oneshot", function() end)
end

local profiles = {"Quiet", "Balanced", "Performance"}

local function profileGlyph(profile)
  local glyphs = data.glyphs or { quiet = "windmill-off", balanced = "windmill", performance = "windmill-filled" }
  if profile == "Quiet" then return glyphs.quiet
  elseif profile == "Balanced" then return glyphs.balanced
  elseif profile == "Performance" then return glyphs.performance
  else return "circle" end
end

local dropdown_open = { ac = false, battery = false }

local function profileDropdown(title, mode, current_val)
  local buttons = {}
  if dropdown_open[mode] then
    for _, p in ipairs(profiles) do
      if p ~= current_val then
        table.insert(buttons, ui.button({
          key = "dropdown-item-" .. mode .. "-" .. p,
          text = p,
          variant = "ghost",
          onClick = function() 
            dropdown_open[mode] = false
            setProfile(mode, p) 
          end
        }))
      end
    end
  end

  local main_btn = ui.button({
    key = "dropdown-main-" .. mode .. "-" .. tostring(current_val) .. "-" .. (dropdown_open[mode] and "open" or "closed"),
    text = current_val,
    glyph = dropdown_open[mode] and "chevron-up" or "chevron-down",
    variant = "tonal",
    onClick = function()
      dropdown_open[mode] = not dropdown_open[mode]
      render()
    end
  })

  local dd_content
  if dropdown_open[mode] and #buttons > 0 then
    dd_content = ui.column({ key = "dropdown-content-" .. mode, gap = 2, padding = 4 }, buttons)
  end

  local right_side = { main_btn }
  if dd_content then table.insert(right_side, dd_content) end

  return ui.row({ key = "dropdown-row-" .. mode .. "-" .. tostring(current_val), gap = 10, align = "start" }, {
    ui.row({ gap = 10, align = "center", width = 140 }, {
      ui.glyph({ name = profileGlyph(current_val), size = 16, color = "primary" }),
      ui.label({ text = title, fontWeight = "medium" })
    }),
    ui.column({ gap = 2, flexGrow = 1 }, right_side)
  })
end

local function profileRow(title, mode, current_val)
  local buttons = {}
  for _, p in ipairs(profiles) do
    local is_active = (p == current_val)
    local variant = is_active and "primary" or "tonal"
    table.insert(buttons, ui.button({
      key = "profile-btn-" .. mode .. "-" .. p .. "-" .. (is_active and "active" or "inactive"),
      glyph = profileGlyph(p),
      tooltip = p,
      variant = variant,
      width = 55,
      height = 55,
      onClick = function() setProfile(mode, p) end
    }))
  end
  
  return ui.column({ key = "profile-col-" .. mode .. "-" .. tostring(current_val), gap = 15, align = "center" }, {
    ui.label({ text = title, fontWeight = "bold" }),
    ui.row({ key = "profile-row-" .. mode .. "-" .. tostring(current_val), gap = 30, justify = "center" }, buttons)
  })
end

function render()
  local current_limit = 100
  if data.charge_limit then
    local num = tonumber(data.charge_limit:match("%d+"))
    if num then current_limit = num end
  end

  local limit_slider = ui.column({ gap = 5 }, {
    ui.label({ text = "Battery Charge Limit: " .. tostring(current_limit) .. "%", fontWeight = "bold" }),
    ui.slider({
      min = 20,
      max = 100,
      step = 5,
      value = current_limit,
      onChange = function(val) setLimit(val) end
    })
  })

  local oneshot_btn = ui.button({
    text = "One-Shot Charge",
    glyph = "battery-charging",
    variant = "tonal",
    onClick = oneshot
  })

  local show_ac_batt = noctalia.getConfig("show_ac_batt_profiles")
  if show_ac_batt == nil then show_ac_batt = true end

  local children = {
    profileRow("Active Profile", "active", data.active_profile),
    ui.separator({ spacing = 5 })
  }

  if show_ac_batt then
    table.insert(children, profileDropdown("AC Profile", "ac", data.ac_profile))
    table.insert(children, profileDropdown("Battery Profile", "battery", data.battery_profile))
    table.insert(children, ui.separator({ spacing = 5 }))
  end

  table.insert(children, limit_slider)
  table.insert(children, ui.separator({ spacing = 5 }))
  table.insert(children, oneshot_btn)

  local has_card_borders = noctalia.getSetting("shell.card_borders")
  local b_width = (has_card_borders == false) and 0 or 1
  local b_color = (has_card_borders == false) and "transparent" or "outline"
  
  local tm = noctalia.getSetting("shell.panels.transparency_mode") or "glass"
  local card_fill = "surface_variant"
  if tm == "glass" then
    card_fill = "surface_variant/0.6"
  elseif tm == "soft" then
    card_fill = "surface_variant"
  end

  local content = ui.column({ 
    gap = 7, 
    padding = 15,
    fill = card_fill,
    border = b_color,
    borderWidth = b_width,
    radius = radius
  }, children)

  panel.render(ui.column({
    flexGrow = 1,
    radius = radius,
    onRightClick = function() panel.openContextMenu() end
  }, { ui.scroll({ flexGrow = 1, padding = 15 }, { content }) }))
end

noctalia.state.watch("asusctl_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

render()
