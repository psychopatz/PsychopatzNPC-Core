PNC = PNC or {}
PNC.CharacterWindowTabs = PNC.CharacterWindowTabs or {}

local Tabs = PNC.CharacterWindowTabs

local function line(window, label, value, y)
    window:drawText(tostring(label) .. ": " .. tostring(value), 18, y, 0.93, 0.93, 0.93, 1, UIFont.Small)
    return y + 18
end

function Tabs.RenderInfo(window, snapshot, topY)
    local data = snapshot and snapshot.characterWindow or {}
    local y = topY
    y = line(window, "Name", data.displayName or snapshot.name or "Unknown", y)
    y = line(window, "Archetype", data.archetypeLabel or snapshot.archetypeLabel or "-", y)
    y = line(window, "Faction", snapshot.faction or "-", y)
    y = line(window, "AI State", snapshot.aiState or "-", y)
    y = line(window, "Presence", snapshot.presenceState or "-", y)
    y = line(window, "Identity Seed", data.identitySeed or snapshot.identitySeed or 1, y)
    y = line(window, "Weapon", snapshot.weaponFullType or "Bare hands", y)
    y = line(window, "Combat Mode", snapshot.combatModeResolved or snapshot.weaponMode or "melee", y)
    y = line(window, "Recruited", (snapshot.recruited == true) and "Yes" or "No", y)
    y = line(window, "Owner", data.ownerUsername or "-", y)
    return y
end

