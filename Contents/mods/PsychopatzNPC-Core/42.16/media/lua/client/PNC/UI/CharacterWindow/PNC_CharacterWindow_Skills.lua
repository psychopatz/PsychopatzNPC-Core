PNC = PNC or {}
PNC.CharacterWindowTabs = PNC.CharacterWindowTabs or {}

local Tabs = PNC.CharacterWindowTabs
local Catalog = PNC.SkillCatalog

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function Tabs.RenderSkills(window, snapshot, topY)
    local groups = Catalog.GetGroups()
    local skillLevels = snapshot and snapshot.skillLevels or {}
    local y = topY - (window.scrollY or 0)
    local i
    local j
    local group
    local skill
    local boxX = window.width - 150

    for i = 1, #groups do
        group = groups[i]
        window:drawRect(10, y, window.width - 20, 22, 0.22, 0.1, 0.1, 0.1)
        window:drawText(group.display, 16, y + 4, 1, 1, 1, 1, UIFont.Medium)
        y = y + 28
        for j = 1, #(group.skills or {}) do
            local level = clamp(math.floor(tonumber(skillLevels[group.skills[j].id] or 0)), 0, 10)
            local k
            skill = group.skills[j]
            window:drawText(skill.display, 28, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
            for k = 0, 9 do
                window:drawRectBorder(boxX + (k * 12), y + 2, 10, 10, 0.9, 0.6, 0.6, 0.6)
                if k < level then
                    window:drawRect(boxX + (k * 12) + 1, y + 3, 8, 8, 0.92, 0.82, 0.82, 0.82)
                end
            end
            y = y + 16
        end
        y = y + 12
    end

    window.maxScroll = math.max(0, y - (window.height - 32))
    window.scrollY = clamp(window.scrollY or 0, 0, window.maxScroll)
    return y
end

