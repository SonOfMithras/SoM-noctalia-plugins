-- Cycle AsusCtl profile (Quiet, Balanced, Performance)

local current_profile = "Unknown"
local current_data = nil

local function applyStatus(data)
    current_data = type(data) == "table" and data or nil
    if current_data and current_data.active_profile then
        current_profile = current_data.active_profile
    end

    if current_profile == "Unknown" then
        shortcut.setLabel("Unknown")
        shortcut.setIcon("windmill", "windmill")
        shortcut.setActive(false)
        shortcut.setEnabled(false)
        return
    end

    local glyph = "windmill"
    local active = false

    local glyphs = current_data and current_data.glyphs or { quiet = "windmill-off", balanced = "windmill", performance = "windmill-filled" }

    if current_profile == "Quiet" then
        glyph = glyphs.quiet
    elseif current_profile == "Balanced" then
        glyph = glyphs.balanced
    elseif current_profile == "Performance" then
        glyph = glyphs.performance
        active = true
    end

    shortcut.setLabel(current_profile)
    shortcut.setIcon(glyph, "windmill")
    shortcut.setActive(active)
    shortcut.setEnabled(true)
end

applyStatus(noctalia.state.get("asus_laptop_controls_data"))
noctalia.state.watch("asus_laptop_controls_data", applyStatus)

function onClick()
    if current_profile == "Unknown" then return end
    
    local next_profile = "Balanced"
    if current_profile == "Quiet" then
        next_profile = "Balanced"
    elseif current_profile == "Balanced" then
        next_profile = "Performance"
    elseif current_profile == "Performance" then
        next_profile = "Quiet"
    end
    
    noctalia.runAsync("asusctl profile set " .. next_profile, function() end)
    
    if current_data then
        current_data.active_profile = next_profile
        noctalia.state.set("asus_laptop_controls_data", current_data)
    end
end
