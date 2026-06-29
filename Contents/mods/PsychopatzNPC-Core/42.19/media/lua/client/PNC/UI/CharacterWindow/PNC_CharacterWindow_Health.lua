PNC = PNC or {}
PNC.CharacterWindowTabs = PNC.CharacterWindowTabs or {}

local Tabs = PNC.CharacterWindowTabs

local function line(window, label, value, y)
    window:drawText(tostring(label) .. ": " .. tostring(value), 18, y, 0.93, 0.93, 0.93, 1, UIFont.Small)
    return y + 18
end

function Tabs.RenderHealth(window, snapshot, payload, topY)
    local data = payload and payload.snapshot and payload.snapshot.characterWindow or snapshot and snapshot.characterWindow or {}
    local stamina = payload and payload.stamina or {}
    local y = topY
    y = line(window, "Health", tostring(snapshot.hpCurrent or 0) .. "/" .. tostring(snapshot.hpMax or 0), y)
    y = line(window, "Health State", snapshot.healthState or "normal", y)
    y = line(window, "Stamina", tostring(math.floor((tonumber(stamina.current or snapshot.staminaCurrent) or 0) + 0.5))
        .. "/" .. tostring(math.floor((tonumber(stamina.max or snapshot.staminaMax) or 0) + 0.5)), y)
    y = line(window, "Stamina State", stamina.state or snapshot.staminaState or "fresh", y)
    y = line(window, "Can Revive", data.canRevive == true and "Yes" or "No", y)
    y = line(window, "Incapacitated", snapshot.healthState == "incapacitated" and "Yes" or "No", y)
    y = y + 8
    window:drawText("Medical adapter shell", 18, y, 0.86, 0.86, 0.86, 1, UIFont.Medium)
    y = y + 20
    window:drawText("This tab is owned by PNC and stays player-independent.", 18, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    y = y + 18
    window:drawText("Future bandage, wounds, and revive actions plug into this host.", 18, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    return y + 18
end
