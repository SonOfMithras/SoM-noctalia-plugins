function toggle_touchpad()
  local script_path = noctalia.pluginDir() .. "/asus-laptop-controls-touchpad.sh"
  local cmd = "bash " .. string.format("%q", script_path) .. " toggle 2>/dev/null || asus-laptop-controls-touchpad toggle 2>/dev/null || true"
  noctalia.runAsync(cmd, function() end)
end

function onIpc(event, payload)
  if event == "toggle" then
    toggle_touchpad()
  end
end
