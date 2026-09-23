local interval = (noctalia.getConfig("update_interval_sec") or 5.0) * 1000


local home = noctalia.getenv("HOME") or "/home/ammar"
local cfg_dir = home .. "/.local/share/noctalia/plugins/asus-laptop-controls"
local cfg_file = cfg_dir .. "/config.json"

local saved_timeout = nil
local saved_brightness = nil
local saved_gestures = nil

local raw_cfg = noctalia.readFile(cfg_file)
if raw_cfg and raw_cfg ~= "" then
  local ok, parsed = pcall(function() return noctalia.json.decode(raw_cfg) end)
  if ok and type(parsed) == "table" then
    if parsed.kbd_timeout and tonumber(parsed.kbd_timeout) then
      saved_timeout = tonumber(parsed.kbd_timeout)
    end
    if parsed.kbd_brightness and tonumber(parsed.kbd_brightness) then
      saved_brightness = tonumber(parsed.kbd_brightness)
    end
    if parsed.gestures_enabled ~= nil then
      saved_gestures = parsed.gestures_enabled
    end
  end
end

local data = noctalia.state.get("asus_laptop_controls_data") or {
  active_profile = "Unknown",
  ac_profile = "Unknown",
  battery_profile = "Unknown",
  charge_limit = "Unknown",
  glyphs = {
    quiet = noctalia.getConfig("glyph_quiet") or "windmill-off",
    balanced = noctalia.getConfig("glyph_balanced") or "windmill",
    performance = noctalia.getConfig("glyph_performance") or "windmill-filled"
  },
  services_installed = false,
  gestures_enabled = (saved_gestures ~= nil) and saved_gestures or (noctalia.getConfig("gestures_enabled") ~= false),
  kbd_brightness = (saved_brightness ~= nil) and saved_brightness or tonumber(noctalia.getConfig("kbd_brightness")) or 1,
  kbd_timeout = saved_timeout or 15,
  touchpad_enabled = true
}

if saved_timeout and data.kbd_timeout ~= saved_timeout then
  data.kbd_timeout = saved_timeout
end
if saved_brightness ~= nil and data.kbd_brightness ~= saved_brightness then
  data.kbd_brightness = saved_brightness
end

local function saveConfig()
  local is_enabled = (data.gestures_enabled ~= false and noctalia.getConfig("gestures_enabled") ~= false)
  local kbd_b = tonumber(data.kbd_brightness)
  if kbd_b == nil then kbd_b = 1 end
  local kbd_t = tonumber(data.kbd_timeout) or 15

  local config_table = {
    kbd_timeout = kbd_t,
    kbd_brightness = kbd_b,
    gestures_enabled = is_enabled,
    left_edge_up = noctalia.getConfig("left_edge_up") or "noctalia msg brightness-up",
    left_edge_down = noctalia.getConfig("left_edge_down") or "noctalia msg brightness-down",
    right_edge_up = noctalia.getConfig("right_edge_up") or "noctalia msg volume-up",
    right_edge_down = noctalia.getConfig("right_edge_down") or "noctalia msg volume-down",
    top_edge_left = noctalia.getConfig("top_edge_left") or "noctalia msg media toggle",
    top_edge_right = noctalia.getConfig("top_edge_right") or "noctalia msg media toggle"
  }

  local json_str = noctalia.json.encode(config_table)
  local cmd = string.format("mkdir -p %q && printf '%%s\\n' %q > %q && systemctl --user restart asus-laptop-controls-gestures.service 2>/dev/null || true", cfg_dir, json_str, cfg_file)
  noctalia.runAsync(cmd, function() end)
end

-- Only save initial config if config.json does not exist yet on disk
if not raw_cfg or raw_cfg == "" then
  saveConfig()
end

noctalia.state.set("asus_laptop_controls_data", data)

noctalia.state.watch("asus_laptop_controls_data", function(new_data)
  if type(new_data) == "table" then
    local prev_gestures = data.gestures_enabled
    local prev_b = data.kbd_brightness
    local prev_t = data.kbd_timeout
    for k, v in pairs(new_data) do
      data[k] = v
    end
    if prev_gestures ~= data.gestures_enabled or prev_b ~= data.kbd_brightness or prev_t ~= data.kbd_timeout then
      saveConfig()
    end
  end
end)

function update()
  noctalia.setUpdateInterval(interval)

  noctalia.runAsync("test -f /usr/local/bin/asus-laptop-controls-gestures-daemon && echo 'yes' || echo 'no'", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    local is_installed = type(out) == "string" and out:match("yes") ~= nil
    if data.services_installed ~= is_installed then
      data.services_installed = is_installed
      noctalia.state.set("asus_laptop_controls_data", data)
    end
  end)

  noctalia.runAsync("systemctl --user is-active asus-laptop-controls-gestures.service 2>/dev/null", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    local is_active = type(out) == "string" and out:match("^active") ~= nil
    if data.gestures_service_active ~= is_active then
      data.gestures_service_active = is_active
      noctalia.state.set("asus_laptop_controls_data", data)
    end
  end)

  noctalia.runAsync("systemctl is-active asus-laptop-controls-kbd.service 2>/dev/null", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    local is_active = type(out) == "string" and out:match("^active") ~= nil
    if data.kbd_service_active ~= is_active then
      data.kbd_service_active = is_active
      noctalia.state.set("asus_laptop_controls_data", data)
    end
  end)

  local tp_script = noctalia.pluginDir() .. "/asus-laptop-controls-touchpad.sh"
  noctalia.runAsync("bash " .. string.format("%q", tp_script) .. " status 2>/dev/null || asus-laptop-controls-touchpad status 2>/dev/null", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    if type(out) == "string" then
      local is_enabled = (out:match("enabled") ~= nil and out:match("disabled") == nil)
      if data.touchpad_enabled ~= is_enabled then
        data.touchpad_enabled = is_enabled
        noctalia.state.set("asus_laptop_controls_data", data)
      end
    end
  end)

  noctalia.runAsync("asusctl profile get", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    if type(out) == "string" then
      local active = out:match("Active profile:%s*([^\n]+)")
      if active then data.active_profile = active:match("^%s*(.-)%s*$") end
      
      local ac = out:match("AC profile%s*([^\n]+)")
      if ac then data.ac_profile = ac:match("^%s*(.-)%s*$") end
      
      local bat = out:match("Battery profile%s*([^\n]+)")
      if bat then data.battery_profile = bat:match("^%s*(.-)%s*$") end
    end
    noctalia.state.set("asus_laptop_controls_data", data)
  end)

  noctalia.runAsync("asusctl battery info", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    if type(out) == "string" then
      local limit = out:match("limit:%s*(%d+%%?)")
      if limit then
        data.charge_limit = limit
      end
    end
    noctalia.state.set("asus_laptop_controls_data", data)
  end)
end

function onConfigChanged()
  saveConfig()
end

function onExit(_signal, reason)
  if reason == "disable" or reason == "uninstall" then
    noctalia.runAsync("systemctl --user stop asus-laptop-controls-gestures.service 2>/dev/null || true", function() end)
    
    if reason == "uninstall" then
      noctalia.runAsync("systemctl --user disable asus-laptop-controls-gestures.service 2>/dev/null || true", function() end)
      local script_path = noctalia.pluginDir() .. "/uninstall.sh"
      noctalia.runAsync("pkexec /usr/bin/bash " .. string.format("%q", script_path) .. " 2>/dev/null || true", function() end)
    end
  end
end


