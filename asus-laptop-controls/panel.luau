local scale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
local radius = 10 * scale

local home = noctalia.getenv("HOME") or "/home/ammar"
local cfg_dir = home .. "/.local/share/noctalia/plugins/asus-laptop-controls"
local cfg_file = cfg_dir .. "/config.json"

local disk_timeout = nil
local disk_brightness = nil
local raw_cfg = noctalia.readFile(cfg_file)
if raw_cfg and raw_cfg ~= "" then
  local ok, parsed = pcall(function() return noctalia.json.decode(raw_cfg) end)
  if ok and type(parsed) == "table" then
    if parsed.kbd_timeout and tonumber(parsed.kbd_timeout) then
      disk_timeout = tonumber(parsed.kbd_timeout)
    end
    if parsed.kbd_brightness and tonumber(parsed.kbd_brightness) then
      disk_brightness = tonumber(parsed.kbd_brightness)
    end
  end
end

local data = noctalia.state.get("asus_laptop_controls_data") or {
  active_profile = "Unknown",
  ac_profile = "Unknown",
  battery_profile = "Unknown",
  charge_limit = "Unknown",
  gestures_enabled = true,
  kbd_brightness = (disk_brightness ~= nil) and disk_brightness or 1,
  kbd_timeout = disk_timeout or 15
}

if disk_timeout and data.kbd_timeout ~= disk_timeout then
  data.kbd_timeout = disk_timeout
end
if disk_brightness ~= nil and data.kbd_brightness ~= disk_brightness then
  data.kbd_brightness = disk_brightness
end

local function setProfile(mode, profile)
  local cmd = "asusctl profile set "
  if mode == "ac" then
    cmd = cmd .. "-a "
  elseif mode == "battery" then
    cmd = cmd .. "-b "
  end
  cmd = cmd .. profile
  
  if mode == "active" then
    data.active_profile = profile
  elseif mode == "ac" then
    data.ac_profile = profile
  elseif mode == "battery" then
    data.battery_profile = profile
  end
  noctalia.state.set("asus_laptop_controls_data", data)
  render()
  
  noctalia.runAsync(cmd, function() end)
end

local function setLimit(val)
  data.charge_limit = tostring(val) .. "%"
  noctalia.state.set("asus_laptop_controls_data", data)
  render()
  noctalia.runAsync("asusctl battery limit " .. tostring(val), function() end)
end

local function setKbdBrightness(val)
  local num = tonumber(val)
  if num == nil then num = 1 end
  data.kbd_brightness = num
  noctalia.state.set("asus_laptop_controls_data", data)
  render()
  noctalia.runAsync("brightnessctl -sd asus::kbd_backlight set " .. tostring(num), function() end)

  local raw = noctalia.readFile(cfg_file)
  local cfg = {}
  if raw and raw ~= "" then
    local ok, parsed = pcall(function() return noctalia.json.decode(raw) end)
    if ok and type(parsed) == "table" then cfg = parsed end
  end
  cfg.kbd_brightness = num
  local json_str = noctalia.json.encode(cfg)
  local cmd = string.format("mkdir -p %q && printf '%%s\\n' %q > %q", cfg_dir, json_str, cfg_file)
  noctalia.runAsync(cmd, function() end)
end

local function setKbdTimeout(val)
  local num = tonumber(val) or 15
  data.kbd_timeout = num
  noctalia.state.set("asus_laptop_controls_data", data)
  render()

  local raw = noctalia.readFile(cfg_file)
  local cfg = {}
  if raw and raw ~= "" then
    local ok, parsed = pcall(function() return noctalia.json.decode(raw) end)
    if ok and type(parsed) == "table" then cfg = parsed end
  end
  cfg.kbd_timeout = num
  local json_str = noctalia.json.encode(cfg)
  local cmd = string.format("mkdir -p %q && printf '%%s\\n' %q > %q", cfg_dir, json_str, cfg_file)
  noctalia.runAsync(cmd, function() end)
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
local confirming_install = false
local confirming_uninstall = false
local restarting_services = false

local function restartServices()
  if restarting_services then return end
  local gestures_active = data.gestures_service_active == true
  local kbd_active = data.kbd_service_active == true
  if not gestures_active and not kbd_active then return end

  restarting_services = true
  render()

  if gestures_active then
    noctalia.runAsync("systemctl --user restart asus-laptop-controls-gestures.service 2>/dev/null || true", function() end)
  end
  if kbd_active then
    noctalia.runAsync("pkexec systemctl restart asus-laptop-controls-kbd.service", function() end)
  end

  noctalia.runAsync("sleep 1", function()
    restarting_services = false
    render()
  end)
end

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

  return ui.row({ key = "dropdown-row-" .. mode .. "-" .. tostring(current_val), gap = 10, align = "center" }, {
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
  local children = {}
  
  if data.services_installed == false then
    if not confirming_install then
      table.insert(children, ui.column({ gap = 8, padding = 12, fill = "error/0.15", radius = radius }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.glyph({ name = "alert-triangle", size = 18, color = "error" }),
          ui.label({ text = "Services Not Installed", fontWeight = "bold", color = "error" })
        }),
        ui.label({ text = "The gestures daemon and keyboard backlight manager require root privileges to install." }),
        ui.button({
          text = "Install Services...",
          variant = "filled",
          onClick = function()
            confirming_install = true
            render()
          end
        })
      }))
    else
      table.insert(children, ui.column({ gap = 8, padding = 12, fill = "primary/0.15", radius = radius }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.glyph({ name = "settings", size = 18, color = "primary" }),
          ui.label({ text = "Install Services", fontWeight = "bold", color = "primary" })
        }),
        ui.label({ text = "Do you want to enable and start the services immediately?" }),
        ui.row({ gap = 10, align = "center" }, {
          ui.button({
            text = "Install & Enable",
            variant = "filled",
            onClick = function()
              confirming_install = false
              render()
              local script_path = noctalia.pluginDir() .. "/install.sh"
              local cmd = "pkexec /usr/bin/bash " .. string.format("%q", script_path) .. " --enable"
              noctalia.runAsync(cmd, function()
                noctalia.runAsync("systemctl --user daemon-reload && systemctl --user enable --now asus-laptop-controls-gestures.service 2>/dev/null || true", function() end)
              end)
            end
          }),
          ui.button({
            text = "Install Only",
            variant = "tonal",
            onClick = function()
              confirming_install = false
              render()
              local script_path = noctalia.pluginDir() .. "/install.sh"
              local cmd = "pkexec /usr/bin/bash " .. string.format("%q", script_path) .. " --no-enable"
              noctalia.runAsync(cmd, function()
                noctalia.runAsync("systemctl --user daemon-reload", function() end)
              end)
            end
          }),
          ui.button({
            text = "Cancel",
            variant = "ghost",
            onClick = function()
              confirming_install = false
              render()
            end
          })
        })
      }))
    end
    table.insert(children, ui.separator({ spacing = 5 }))
  end

  -- Active Power Profile (Hero widget at top)
  table.insert(children, profileRow("Active Profile", "active", data.active_profile))
  table.insert(children, ui.separator({ spacing = 8 }))

  local show_ac_batt = noctalia.getConfig("show_ac_batt_profiles")
  if show_ac_batt == nil then show_ac_batt = true end
  
  if show_ac_batt then
    table.insert(children, profileDropdown("AC", "ac", data.ac_profile))
    table.insert(children, profileDropdown("Battery", "battery", data.battery_profile))
    table.insert(children, ui.separator({ spacing = 8 }))
  end

  -- Battery Health & Charge Limit (Grouped together)
  table.insert(children, ui.label({ text = "Battery", fontWeight = "medium", align = "center", color = "on_surface_variant" }))
  
  local current_limit = 100
  if data.charge_limit then
    local num = tonumber(data.charge_limit:match("%d+"))
    if num then current_limit = num end
  end

  table.insert(children, ui.column({ gap = 5 }, {
    ui.label({ text = "Battery Charge Limit: " .. tostring(current_limit) .. "%", fontWeight = "medium" }),
    ui.slider({
      min = 20,
      max = 100,
      step = 5,
      value = current_limit,
      onChange = function(val) setLimit(val) end
    })
  }))

  table.insert(children, ui.button({
    text = "One-Shot Charge",
    glyph = "battery-charging",
    variant = "tonal",
    onClick = oneshot
  }))
  table.insert(children, ui.separator({ spacing = 10 }))

  -- Keyboard Backlight & Idle Timeout Controls
  table.insert(children, ui.label({ text = "Keyboard Backlight", fontWeight = "medium", align = "center", color = "on_surface_variant" }))

  local kbd_brightness = tonumber(data.kbd_brightness)
  if kbd_brightness == nil then kbd_brightness = 1 end
  local kbd_timeout = tonumber(data.kbd_timeout) or 15

  local kbd_levels = {
    { val = 0, label = "Off" },
    { val = 1, label = "Low" },
    { val = 2, label = "Med" },
    { val = 3, label = "High" }
  }

  local level_buttons = {}
  for _, lvl in ipairs(kbd_levels) do
    local is_sel = (kbd_brightness == lvl.val)
    table.insert(level_buttons, ui.button({
      key = "kbd-lvl-" .. lvl.val .. "-" .. (is_sel and "active" or "inactive"),
      text = lvl.label,
      variant = is_sel and "primary" or "tonal",
      controlSize = "sm",
      onClick = function()
        setKbdBrightness(lvl.val)
      end
    }))
  end

  table.insert(children, ui.row({ gap = 10, align = "center", justify = "space-between" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "keyboard", size = 18, color = "primary" }),
      ui.label({ text = "Brightness", fontWeight = "medium" })
    }),
    ui.row({ gap = 6 }, level_buttons)
  }))

  local timeout_choices = {
    { sec = 1, label = "1 second" },
    { sec = 3, label = "3 seconds" },
    { sec = 5, label = "5 seconds" },
    { sec = 10, label = "10 seconds" },
    { sec = 15, label = "15 seconds (Default)" },
    { sec = 30, label = "30 seconds" },
    { sec = 45, label = "45 seconds" },
    { sec = 60, label = "1 minute" },
    { sec = 120, label = "2 minutes" },
    { sec = 180, label = "3 minutes" },
    { sec = 300, label = "5 minutes" },
    { sec = 600, label = "10 minutes" }
  }

  local has_current = false
  for _, c in ipairs(timeout_choices) do
    if c.sec == kbd_timeout then
      has_current = true
      break
    end
  end

  if not has_current then
    local custom_lbl
    if kbd_timeout < 60 then
      custom_lbl = tostring(kbd_timeout) .. " seconds"
    else
      local m = math.floor(kbd_timeout / 60)
      local s = kbd_timeout % 60
      if s == 0 then
        custom_lbl = tostring(m) .. (m == 1 and " minute" or " minutes")
      else
        custom_lbl = tostring(m) .. "m " .. tostring(s) .. "s"
      end
    end
    table.insert(timeout_choices, { sec = kbd_timeout, label = custom_lbl })
    table.sort(timeout_choices, function(a, b) return a.sec < b.sec end)
  end

  local timeout_options = {}
  local selected_timeout_idx = 0
  for idx, c in ipairs(timeout_choices) do
    table.insert(timeout_options, c.label)
    if c.sec == kbd_timeout then
      selected_timeout_idx = idx - 1
    end
  end

  table.insert(children, ui.column({ gap = 5, align = "stretch" }, {
    ui.label({ text = "Idle Timeout", fontSize = 11, color = "on_surface_variant" }),
    ui.select({
      key = "kbd-timeout-select",
      options = timeout_options,
      selectedIndex = selected_timeout_idx,
      onChange = function(index)
        local chosen = timeout_choices[index + 1]
        if chosen then
          setKbdTimeout(chosen.sec)
        end
      end
    })
  }))
  
  table.insert(children, ui.separator({ spacing = 10 }))

  -- Touchpad & Gestures
  table.insert(children, ui.label({ text = "Touchpad & Gestures", fontWeight = "medium", align = "center", color = "on_surface_variant" }))
  -- Smart Gestures Switch
  local gestures_on = data.gestures_enabled
  if gestures_on == nil then gestures_on = true end
  
  table.insert(children, ui.row({ gap = 10, align = "center", justify = "space-between" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ 
        name =  gestures_on and "hand-click" or "hand-click-off", 
        size = 18, 
        color = gestures_on and "primary" or "outline" 
      }),
      ui.label({ text = "Enable Edge Gestures", fontWeight = "medium" })
    }),
    ui.button({
      text = gestures_on and "ON" or "OFF",
      variant = gestures_on and "filled" or "tonal",
      onClick = function()
        data.gestures_enabled = not gestures_on
        noctalia.state.set("asus_laptop_controls_data", data)
        render()
      end
    })
  }))

  -- Background Services Management (when installed)
  if data.services_installed == true then
    table.insert(children, ui.separator({ spacing = 10 }))
    table.insert(children, ui.label({ text = "Background Services", fontWeight = "medium", align = "center", color = "on_surface_variant" }))
    
    local gestures_active = data.gestures_service_active == true
    local kbd_active = data.kbd_service_active == true

    -- Gestures Daemon Row
    table.insert(children, ui.row({ gap = 10, align = "center", justify = "space-between" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ 
          name = gestures_active and "arrow-move-up", 
          size = 18, 
          color = gestures_active and "primary" or "outline" 
        }),
        ui.column({ gap = 2 }, {
          ui.label({ text = "Gestures Daemon", fontWeight = "medium" }),
          ui.label({ 
            text = gestures_active and "Running (enabled)" or "Stopped (disabled)", 
            fontSize = 11, 
            color = gestures_active and "primary" or "outline" 
          })
        })
      }),
      ui.button({
        text = gestures_active and "Disable" or "Enable",
        variant = gestures_active and "tonal" or "filled",
        controlSize = "sm",
        onClick = function()
          local act = gestures_active and "disable --now" or "enable --now"
          noctalia.runAsync("systemctl --user " .. act .. " asus-laptop-controls-gestures.service 2>/dev/null || true", function() end)
        end
      })
    }))

    -- Keyboard Backlight Manager Row
    table.insert(children, ui.row({ gap = 10, align = "center", justify = "space-between" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ 
          name = kbd_active and "keyboard" or "keyboard-off", 
          size = 18, 
          color = kbd_active and "primary" or "outline" 
        }),
        ui.column({ gap = 2 }, {
          ui.label({ text = "Kbd Backlight Manager", fontWeight = "medium" }),
          ui.label({ 
            text = kbd_active and "Running (enabled)" or "Stopped (disabled)", 
            fontSize = 11, 
            color = kbd_active and "primary" or "outline" 
          })
        })
      }),
      ui.button({
        text = kbd_active and "Disable" or "Enable",
        variant = kbd_active and "tonal" or "filled",
        controlSize = "sm",
        onClick = function()
          local act = kbd_active and "disable --now" or "enable --now"
          local cmd = "pkexec systemctl " .. act .. " asus-laptop-controls-kbd.service"
          noctalia.runAsync(cmd, function() end)
        end
      })
    }))

    -- Action Buttons: Restart Enabled Services & Uninstall
    if not confirming_uninstall then
      table.insert(children, ui.row({ justify = "space-between", align = "center" }, {
        ui.button({
          text = restarting_services and "Restarting..." or "Restart Services",
          glyph = "refresh",
          variant = "tonal",
          controlSize = "sm",
          enabled = not restarting_services and (gestures_active or kbd_active),
          onClick = restartServices
        }),
        ui.button({
          text = "Uninstall Services...",
          glyph = "trash",
          variant = "ghost",
          controlSize = "sm",
          onClick = function()
            confirming_uninstall = true
            render()
          end
        })
      }))
    else
      table.insert(children, ui.column({ gap = 8, padding = 12, fill = "error/0.15", radius = radius }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.glyph({ name = "alert-triangle", size = 18, color = "error" }),
          ui.label({ text = "Uninstall All Services?", fontWeight = "bold", color = "error" })
        }),
        ui.label({ text = "This will stop and remove all background services, binaries, and udev rules." }),
        ui.row({ gap = 10 }, {
          ui.button({
            text = "Confirm Uninstall",
            variant = "filled",
            onClick = function()
              confirming_uninstall = false
              render()
              local script_path = noctalia.pluginDir() .. "/uninstall.sh"
              local cmd = "pkexec /usr/bin/bash " .. string.format("%q", script_path)
              noctalia.runAsync(cmd, function()
                noctalia.runAsync("systemctl --user daemon-reload", function() end)
                data.services_installed = false
                data.gestures_service_active = false
                data.kbd_service_active = false
                noctalia.state.set("asus_laptop_controls_data", data)
                render()
              end)
            end
          }),
          ui.button({
            text = "Cancel",
            variant = "ghost",
            onClick = function()
              confirming_uninstall = false
              render()
            end
          })
        })
      }))
    end
  end

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

noctalia.state.watch("asus_laptop_controls_data", function(new_data)
  if type(new_data) == "table" then
    data = new_data
    render()
  end
end)

render()
