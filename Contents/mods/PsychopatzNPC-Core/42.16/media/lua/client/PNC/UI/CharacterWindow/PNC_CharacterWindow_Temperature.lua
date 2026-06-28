PNC = PNC or {}
PNC.CharacterWindowTabs = PNC.CharacterWindowTabs or {}

local Tabs = PNC.CharacterWindowTabs

function Tabs.RenderTemperature(window, snapshot, topY)
    local y = topY
    window:drawText("Temperature shell", 18, y, 0.95, 0.95, 0.95, 1, UIFont.Medium)
    y = y + 22
    window:drawText("NPC-owned temperature adapters land here instead of binding to player internals.", 18, y, 0.72, 0.72, 0.72, 1, UIFont.Small)
    y = y + 18
    window:drawText("Current stealth: " .. tostring(snapshot and snapshot.debugState and snapshot.debugState.stealthActive == true and "Hidden" or "Normal"), 18, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
    return y + 18
end

