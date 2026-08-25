local interval = (noctalia.getConfig("update_interval_sec") or 5.0) * 1000

local data = {
  active_profile = "Unknown",
  ac_profile = "Unknown",
  battery_profile = "Unknown",
  charge_limit = "Unknown",
  glyphs = {
    quiet = noctalia.getConfig("glyph_quiet") or "windmill-off",
    balanced = noctalia.getConfig("glyph_balanced") or "windmill",
    performance = noctalia.getConfig("glyph_performance") or "windmill-filled"
  }
}

-- Initial state set
noctalia.state.set("asusctl_data", data)

function update()
  noctalia.setUpdateInterval(interval)

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
    noctalia.state.set("asusctl_data", data)
  end)

  noctalia.runAsync("asusctl battery info", function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    if type(out) == "string" then
      local limit = out:match("limit:%s*(%d+%%?)")
      if limit then
        data.charge_limit = limit
      end
    end
    noctalia.state.set("asusctl_data", data)
  end)
end
