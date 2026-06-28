PNC = PNC or {}
PNC.CharacterWindowTabs = PNC.CharacterWindowTabs or {}

local Tabs = PNC.CharacterWindowTabs

function Tabs.RenderProtection(window, snapshot, topY)
    local equipment = snapshot and snapshot.equipmentSummary or {}
    local y = topY
    window:drawText("Protection shell", 18, y, 0.95, 0.95, 0.95, 1, UIFont.Medium)
    y = y + 22
    window:drawText("Primary: " .. tostring(equipment.primaryFullType or "Bare hands"), 18, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
    y = y + 18
    window:drawText("Secondary: " .. tostring(equipment.secondaryFullType or "-"), 18, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
    y = y + 22
    window:drawText("This panel is reserved for armor, clothing defense, and body-zone protection.", 18, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    return y + 18
end

