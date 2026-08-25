local interval = (noctalia.getConfig("update_interval_sec") or 15.0) * 1000
local cpu_cmd = noctalia.getConfig("cpu_cmd") or "sensors -j"
local battery_cmd = noctalia.getConfig("battery_cmd") or "sensors -j"
local npu_cmd = noctalia.getConfig("npu_cmd") or "cat /sys/class/accel/accel*/device/hwmon/hwmon*/power1_input 2>/dev/null"
local gpu_cmd = noctalia.getConfig("gpu_cmd") or "cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null"
local dgpu_cmd = noctalia.getConfig("dgpu_cmd") or ""

local show_system = noctalia.getConfig("show_system") ~= false
local show_cpu = noctalia.getConfig("show_cpu") ~= false
local show_gpu = noctalia.getConfig("show_gpu") ~= false
local show_dgpu = noctalia.getConfig("show_dgpu") ~= false
local show_npu = noctalia.getConfig("show_npu") ~= false
local show_battery_time = noctalia.getConfig("show_battery_time") ~= false
local show_battery_percent = noctalia.getConfig("show_battery_percent") ~= false

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

local chart_time_minutes = noctalia.getConfig("chart_time_minutes") or 5
local MAX_HISTORY = math.max(1, math.floor((chart_time_minutes * 60000) / interval))
local history_file = "/tmp/strix_powermon_history.json"
local history = {
  battery = {},
  cpu = {},
  gpu = {},
  dgpu = {},
  npu = {},
  battery_percent = {},
  battery_time = {}
}

pcall(function()
  local f = io.open(history_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
      local parsed = noctalia.json.decode(content)
      if type(parsed) == "table" then
        for k, v in pairs(parsed) do
          if history[k] and type(v) == "table" then
            history[k] = v
          end
        end
      end
    end
  end
end)

for _, arr in pairs(history) do
  while #arr < MAX_HISTORY do
    table.insert(arr, 1, 0)
  end
  while #arr > MAX_HISTORY do
    table.remove(arr, 1)
  end
end

local function push_history(key, value)
  table.insert(history[key], value)
  while #history[key] > MAX_HISTORY do
    table.remove(history[key], 1)
  end
end

local function parse_fallback_power(out)
  local val = tonumber(out:match("%d+%.?%d*"))
  if val then
    if val > 10000 then val = val / 1000000 end
    return val
  end
  return nil
end

local function format_time(t_str)
  if not t_str then return nil end
  local val, unit = t_str:match("([%d%.]+)%s*(%w+)")
  val = tonumber(val)
  if val and unit then
    if unit:match("^hour") then
      local h = math.floor(val)
      local m = math.floor((val - h) * 60 + 0.5)
      if h > 0 then return string.format("%dh %dm", h, m) else return string.format("%dm", m) end
    elseif unit:match("^minute") then
      return string.format("%dm", math.floor(val + 0.5))
    end
  end
  return t_str
end

local function parse_minutes(t_str)
  if not t_str then return nil end
  local val, unit = t_str:match("([%d%.]+)%s*(%w+)")
  val = tonumber(val)
  if val and unit then
    if unit:match("^hour") then
      return val * 60
    elseif unit:match("^minute") then
      return val
    end
  end
  return nil
end

local function publish()
  noctalia.state.set("powermon_data", {
    battery = data.battery,
    cpu = data.cpu,
    gpu = data.gpu,
    dgpu = data.dgpu,
    npu = data.npu,
    battery_time_label = data.battery_time_label,
    battery_time_val = data.battery_time_val,
    battery_percent = data.battery_percent,
    battery_time_minutes = data.battery_time_minutes,
    history = history
  })
  pcall(function()
    local f = io.open(history_file, "w")
    if f then
      f:write(noctalia.json.encode(history))
      f:close()
    end
  end)
end

local pending_requests = 0

local function check_publish()
  pending_requests = pending_requests - 1
  if pending_requests <= 0 then
    pending_requests = 0
    publish()
  end
end

local function parse_sensors_json_cpu(parsed)
  for k, v in pairs(parsed) do
    if k:match("^amdgpu%-pci") and v.PPT then
      data.cpu = v.PPT.power1_average or v.PPT.power1_input or 0
    end
  end
end

local function parse_sensors_json_battery(parsed)
  for k, v in pairs(parsed) do
    if k:match("^BAT") and v.power1 then
      data.battery = v.power1.power1_input or 0
    end
  end
end

function update()
  push_history("battery", data.battery)
  push_history("cpu", data.cpu)
  push_history("gpu", data.gpu)
  push_history("dgpu", data.dgpu)
  push_history("npu", data.npu)
  push_history("battery_percent", data.battery_percent)
  push_history("battery_time", data.battery_time_minutes)
  
  noctalia.setUpdateInterval(interval)
  
  pending_requests = 0
  if show_battery_time or show_battery_percent then pending_requests = pending_requests + 1 end
  
  local combined_cpu_batt = false
  if show_cpu and show_system and cpu_cmd == battery_cmd then
    combined_cpu_batt = true
    pending_requests = pending_requests + 1
  else
    if show_cpu then pending_requests = pending_requests + 1 end
    if show_system then pending_requests = pending_requests + 1 end
  end

  if show_npu then pending_requests = pending_requests + 1 end
  if show_gpu or show_dgpu then pending_requests = pending_requests + 1 end
  if show_dgpu and dgpu_cmd ~= "" then pending_requests = pending_requests + 1 end

  if pending_requests == 0 then
    publish()
    return
  end

  -- Battery Time & Percent
  if show_battery_time or show_battery_percent then
    noctalia.runAsync("upower -i /org/freedesktop/UPower/devices/DisplayDevice", function(res)
      local out = type(res) == "table" and (res.stdout or res.body) or res
      if type(out) == "string" then
        local time_full = out:match("time to full:%s*([^\n]+)")
        local time_empty = out:match("time to empty:%s*([^\n]+)")
        local percentage = out:match("percentage:%s*(%d+)%%")
        
        if percentage then data.battery_percent = tonumber(percentage) end
        
        local mins = nil
        if time_full then
          data.battery_time_label = "Time to full"
          data.battery_time_val = format_time(time_full)
          mins = parse_minutes(time_full)
        elseif time_empty then
          data.battery_time_label = "Time to empty"
          data.battery_time_val = format_time(time_empty)
          mins = parse_minutes(time_empty)
        else
          data.battery_time_label = nil
          data.battery_time_val = nil
        end
        data.battery_time_minutes = mins or 0
      end
      check_publish()
    end)
  end

  -- CPU / System Combined
  if combined_cpu_batt then
    noctalia.runAsync(cpu_cmd, function(res)
      local out = type(res) == "table" and (res.stdout or res.body) or res
      if type(out) == "string" then
        if cpu_cmd:match("sensors %-j") then
          local success, parsed = pcall(function() return noctalia.json.decode(out) end)
          if success and parsed then
            parse_sensors_json_cpu(parsed)
            parse_sensors_json_battery(parsed)
          end
        else
          local val = parse_fallback_power(out)
          if val then
            data.cpu = val
            data.battery = val
          end
        end
      end
      check_publish()
    end)
  else
    if show_cpu then
      noctalia.runAsync(cpu_cmd, function(res)
        local out = type(res) == "table" and (res.stdout or res.body) or res
        if type(out) == "string" then
          if cpu_cmd:match("sensors %-j") then
            local success, parsed = pcall(function() return noctalia.json.decode(out) end)
            if success and parsed then parse_sensors_json_cpu(parsed) end
          else
            local val = parse_fallback_power(out)
            if val then data.cpu = val end
          end
        end
        check_publish()
      end)
    end

    if show_system then
      noctalia.runAsync(battery_cmd, function(res)
        local out = type(res) == "table" and (res.stdout or res.body) or res
        if type(out) == "string" then
          if battery_cmd:match("sensors %-j") then
            local success, parsed = pcall(function() return noctalia.json.decode(out) end)
            if success and parsed then parse_sensors_json_battery(parsed) end
          else
            local val = parse_fallback_power(out)
            if val then data.battery = val end
          end
        end
        check_publish()
      end)
    end
  end

  -- NPU
  if show_npu then
    noctalia.runAsync(npu_cmd, function(res)
      local out = type(res) == "table" and (res.stdout or res.body) or res
      if type(out) == "string" then
        if npu_cmd:match("xrt%-smi") then
          local val = out:match("[Pp]ower%s*[:=]%s*(%d+%.?%d*)")
          if val then data.npu = tonumber(val) or 0 end
        else
          local val = parse_fallback_power(out)
          if val then data.npu = val end
        end
      end
      check_publish()
    end)
  end

  -- GPU
  if show_gpu or show_dgpu then
    noctalia.runAsync(gpu_cmd, function(res)
      local out = type(res) == "table" and (res.stdout or res.body) or res
      if type(out) == "string" then
        if gpu_cmd:match("amdgpu_top.*json") then
          local success, parsed = pcall(function() return noctalia.json.decode(out) end)
          if success and parsed and type(parsed) == "table" then
             local total_igpu_w = 0
             local total_dgpu_w = 0
             if parsed.devices then
               for _, dev in ipairs(parsed.devices) do
                 if type(dev) == "table" then
                   local power_w = nil
                   if dev.Sensors then
                     if dev.Sensors["Average Power"] and dev.Sensors["Average Power"].value then
                       power_w = tonumber(dev.Sensors["Average Power"].value)
                     elseif dev.Sensors["Input Power"] and dev.Sensors["Input Power"].value then
                       power_w = tonumber(dev.Sensors["Input Power"].value)
                     end
                   end
                   
                   if power_w then
                     total_dgpu_w = total_dgpu_w + power_w
                   elseif dev.gpu_metrics then
                     local gfx_power = tonumber(dev.gpu_metrics.average_gfx_power) or 0
                     local dgpu_power = tonumber(dev.gpu_metrics.average_dgpu_power) or 0
                     if gfx_power > 0 then total_igpu_w = total_igpu_w + (gfx_power / 1000) end
                     if dgpu_power > 0 then total_dgpu_w = total_dgpu_w + (dgpu_power / 1000) end
                   end
                 end
               end
             end
             data.gpu = total_igpu_w
             data.dgpu = total_dgpu_w
          end
        else
          local val = parse_fallback_power(out)
          if val then data.gpu = val end
        end
      end
      check_publish()
    end)
  end

  -- dGPU explicit command (Overrides auto-detection if set)
  if show_dgpu and dgpu_cmd ~= "" then
    noctalia.runAsync(dgpu_cmd, function(res)
      local out = type(res) == "table" and (res.stdout or res.body) or res
      if type(out) == "string" then
        local val = parse_fallback_power(out)
        if val then data.dgpu = val end
      end
      check_publish()
    end)
  end
end
