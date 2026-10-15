-- ============================================================================
-- UmbrielFXctl - Service Entry
-- ============================================================================
-- Principles:
-- 1. Multi-Slot Architecture:
--    Manages 6 independent effect include files:
--    - umbriel-effect-workspace.toml (Workspace transitions)
--    - umbriel-effect-in-out.toml     (Window opening/closing lifecycle)
--    - umbriel-effect-move.toml       (Window movement & resize deformation)
--    - umbriel-effect-misc.toml       (Misc window shaders, overlays & screen FX)
--    - umbriel-effect-border.toml     (Focused window border shaders)
--    - umbriel-effect-cursor.toml     (Pointer trails and cursor FX)
--    Allows one effect of each type to be active simultaneously!
-- 2. State Publishing:
--    Publishes the discovered animations list and multi-slot active status
--    to `noctalia.state`, enabling the declarative UI to reactively render.
-- ============================================================================

local interval = (noctalia.getConfig("update_interval_sec") or 5.0) * 1000
local plugin_dir = noctalia.pluginDir() or ""
local helper_script = plugin_dir .. "/bin/umbriel-effects.py"

local data = {
  is_configured = false,
  slots = {},
  active_effects = {},
  effect_names = {},
  effects = {},
  last_updated = os.time(),
  status_message = "Initializing..."
}

-- Initial state publish
noctalia.state.set("umbriel_effects_data", data)

-- Helper to safely execute the python backend
local function runHelper(subcmd, args, callback)
  local cmd = string.format("python3 %q %s", helper_script, subcmd)
  if args and args ~= "" then
    cmd = cmd .. " " .. args
  end

  noctalia.runAsync(cmd, function(res)
    local out = type(res) == "table" and (res.stdout or res.body) or res
    if type(out) == "string" and out ~= "" then
      local ok, parsed = pcall(function() return noctalia.json.decode(out) end)
      if ok and type(parsed) == "table" then
        if callback then callback(parsed) end
        return
      end
    end
    if callback then callback(nil) end
  end)
end

-- Refresh status and effects list
local function refreshAll()
  -- 1. Fetch current status across all 6 slots
  runHelper("status", "", function(status_res)
    if status_res then
      data.is_configured = true
      data.slots = status_res.slots or {}
      data.active_effects = status_res.active_effects or {}
      data.effect_names = status_res.effect_names or {}
    end

    -- 2. Fetch list of available effects if not yet loaded
    if #data.effects == 0 then
      runHelper("list", "", function(list_res)
        if list_res and type(list_res) == "table" then
          data.effects = list_res
        end
        data.last_updated = os.time()
        noctalia.state.set("umbriel_effects_data", data)
      end)
    else
      data.last_updated = os.time()
      noctalia.state.set("umbriel_effects_data", data)
    end
  end)
end

-- Helper to setup or resetup config files and register includes in config.toml
local function setupConfigs(callback)
  runHelper("setup", "", function(res)
    local created = (res and res.files_created and #res.files_created) or 0
    if res and res.ok then
      if created > 0 or (res and res.config_updated) then
        noctalia.notify("UmbrielFXctl Setup", string.format("Created %d effect file(s) and registered includes in config.toml.", created))
      else
        noctalia.notify("UmbrielFXctl Setup", "All 6 effect files and config.toml includes are configured.")
      end
    else
      noctalia.notifyError("UmbrielFXctl Setup Failed", tostring(res and res.error or "Unknown error"))
    end
    refreshAll()
    if callback then callback(res) end
  end)
end

-- Helper to remove config files and clear includes from config.toml
local function removeConfigs(callback)
  runHelper("clean", "", function(res)
    local count = (res and res.files_removed and #res.files_removed) or 0
    local lines = (res and res.lines_cleared and #res.lines_cleared) or 0
    if res and res.ok then
      noctalia.notify("Umbriel Config Removed", string.format("Removed %d effect file(s) and cleared %d include line(s).", count, lines))
    else
      noctalia.notifyError("Umbriel Config Cleanup Failed", tostring(res and res.error or "Unknown error"))
    end
    refreshAll()
    if callback then callback(res) end
  end)
end

-- Initial refresh (does not force recreation of deleted config files)
refreshAll()

-- Periodic update tick
function update()
  noctalia.setUpdateInterval(interval)
  runHelper("status", "", function(status_res)
    if status_res then
      data.slots = status_res.slots or {}
      data.active_effects = status_res.active_effects or {}
      data.effect_names = status_res.effect_names or {}
      data.last_updated = os.time()
      noctalia.state.set("umbriel_effects_data", data)
    end
  end)
end

-- Plugin IPC command entry (e.g. noctalia msg plugin SoM/umbrielfxctl:service all setup)
function onIpc(event, payload)
  if event == "setup" or event == "resetup" then
    setupConfigs()
  elseif event == "remove-config" or event == "remove-configs" or event == "clean" or event == "uninstall" or event == "purge" then
    removeConfigs()
  elseif event == "clear" then
    local slot = payload or "all"
    runHelper("clear", string.format("%q", slot), function()
      refreshAll()
    end)
  elseif event == "apply" and payload then
    runHelper("apply", string.format("%q", payload), function()
      refreshAll()
    end)
  elseif event == "refresh" then
    data.effects = {}
    refreshAll()
  end
end

-- Watch command bus for UI requests
noctalia.state.watch("umbriel_effects_cmd", function(cmd_data)
  if type(cmd_data) ~= "table" or not cmd_data.action then
    return
  end

  local action = cmd_data.action

  if action == "apply" and cmd_data.effect_id then
    runHelper("apply", string.format("%q", cmd_data.effect_id), function(res)
      if res and res.ok then
        local slot_name = res.slot or "slot"
        noctalia.notify("Umbriel Effect Applied", string.format("Activated for %s: %s", slot_name, tostring(cmd_data.effect_id)))
      else
        noctalia.notifyError("Failed to Apply Effect", tostring(res and res.error or "Unknown error"))
      end
      refreshAll()
    end)

  elseif action == "clear" then
    local slot = cmd_data.slot or "all"
    runHelper("clear", string.format("%q", slot), function(res)
      if slot == "all" then
        noctalia.notify("Umbriel Effects Cleared", "Reset all effect slots")
      else
        noctalia.notify("Umbriel Effect Cleared", "Reset " .. slot .. " slot")
      end
      refreshAll()
    end)

  elseif action == "setup" or action == "resetup" then
    setupConfigs()

  elseif action == "remove-configs" or action == "clean" or action == "remove_configs" or action == "uninstall" then
    removeConfigs()

  elseif action == "refresh" then
    data.effects = {} -- force re-scan
    refreshAll()
  end
end)
