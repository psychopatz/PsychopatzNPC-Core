PNC = PNC or {}
PNC.Skills = PNC.Skills or {}

local Skills = PNC.Skills
local Identity = PNC.Identity
local Catalog = PNC.SkillCatalog

local function ensureProgress(record)
    if not record then
        return nil
    end
    record.progression = record.progression or {}
    record.progression.skillXP = record.progression.skillXP or {}
    record.progression.skillLevels = record.progression.skillLevels or {}
    return record.progression
end

local function clampLevel(level)
    return math.max(0, math.min(10, math.floor(tonumber(level) or 0)))
end

local function getSpecialtyMap(record)
    local weaponMode
    local meleeFocus
    local rangedFocus
    if not record then
        return {}
    end
    weaponMode = tostring(record.weaponMode or "melee")
    meleeFocus = {
        "Axe",
        "LongBlade",
        "LongBlunt",
        "ShortBlade",
        "ShortBlunt",
        "Spear",
    }
    rangedFocus = { "Aiming", "Reloading" }
    return {
        melee = meleeFocus[Identity.Index(record.identitySeed, "melee_focus", #meleeFocus)],
        ranged = rangedFocus[Identity.Index(record.identitySeed, "ranged_focus", #rangedFocus)],
        weaponMode = weaponMode,
    }
end

local function resolveBaseLevel(record, skillID)
    local specialty
    local level
    local lowered
    if not record or not skillID then
        return 0
    end

    specialty = getSpecialtyMap(record)
    lowered = string.lower(tostring(skillID))
    level = Identity.Range(record.identitySeed, "skill:" .. tostring(skillID), 0, 3)

    if record.faction == "companion" then
        if lowered == "fitness" or lowered == "strength" or lowered == "nimble" or lowered == "sneaking" then
            level = Identity.Range(record.identitySeed, "skill:" .. tostring(skillID), 1, 4)
        elseif skillID == specialty.melee then
            level = Identity.Range(record.identitySeed, "skill_focus:" .. tostring(skillID), 3, 6)
        elseif skillID == "Maintenance" then
            level = Identity.Range(record.identitySeed, "skill_focus:Maintenance", 1, 4)
        end
    elseif record.faction == "hostile" then
        if specialty.weaponMode == "ranged" and (skillID == "Aiming" or skillID == "Reloading") then
            level = Identity.Range(record.identitySeed, "skill_focus:" .. tostring(skillID), 3, 6)
        elseif skillID == specialty.melee then
            level = Identity.Range(record.identitySeed, "skill_focus:" .. tostring(skillID), 2, 5)
        elseif lowered == "fitness" or lowered == "strength" then
            level = Identity.Range(record.identitySeed, "skill:" .. tostring(skillID), 2, 5)
        end
    elseif lowered == "fitness" or lowered == "strength" then
        level = Identity.Range(record.identitySeed, "skill:" .. tostring(skillID), 1, 3)
    end

    return clampLevel(level)
end

local function resolveXPThreshold(level)
    return 75 + (clampLevel(level) * 30)
end

function Skills.SyncRecruitment(record)
    if not record then
        return false
    end
    if record.recruited == true then
        return true
    end
    record.recruited = record.ownerOnlineID ~= nil or (record.ownerUsername ~= nil and tostring(record.ownerUsername) ~= "")
    return record.recruited == true
end

function Skills.CanLearn(record)
    return Skills.SyncRecruitment(record)
end

function Skills.GetLevel(record, skillID)
    local progression
    local overrides
    local override
    if not record or not skillID then
        return 0
    end
    progression = ensureProgress(record)
    overrides = progression and progression.skillLevels or nil
    override = overrides and overrides[skillID] or nil
    if override ~= nil then
        return clampLevel(override)
    end
    return resolveBaseLevel(record, skillID)
end

function Skills.GetAverage(record, skillIDs)
    local total = 0
    local count = 0
    local i
    if type(skillIDs) ~= "table" then
        return 0
    end
    for i = 1, #skillIDs do
        total = total + Skills.GetLevel(record, skillIDs[i])
        count = count + 1
    end
    if count <= 0 then
        return 0
    end
    return total / count
end

function Skills.AddXP(record, skillID, amount)
    local progression
    local xpMap
    local currentLevel
    local xpValue
    local threshold
    if not Skills.CanLearn(record) or not skillID then
        return false
    end
    progression = ensureProgress(record)
    xpMap = progression.skillXP
    currentLevel = Skills.GetLevel(record, skillID)
    xpValue = math.max(0, tonumber(xpMap[skillID]) or 0) + math.max(0, tonumber(amount) or 0)
    threshold = resolveXPThreshold(currentLevel)
    while xpValue >= threshold and currentLevel < 10 do
        xpValue = xpValue - threshold
        currentLevel = currentLevel + 1
        progression.skillLevels[skillID] = currentLevel
        threshold = resolveXPThreshold(currentLevel)
    end
    xpMap[skillID] = xpValue
    return true
end

function Skills.ResolveWeaponSkill(record, fullType, combatMode)
    local lowered = string.lower(tostring(fullType or ""))
    if tostring(combatMode or "") == "ranged" or lowered:find("shotgun", 1, true) or lowered:find("pistol", 1, true)
        or lowered:find("revolver", 1, true) or lowered:find("rifle", 1, true) or lowered:find("gun", 1, true)
    then
        return "Aiming"
    end
    if lowered:find("axe", 1, true) or lowered:find("hatchet", 1, true) then
        return "Axe"
    end
    if lowered:find("katana", 1, true) or lowered:find("machete", 1, true) or lowered:find("longblade", 1, true) then
        return "LongBlade"
    end
    if lowered:find("spear", 1, true) then
        return "Spear"
    end
    if lowered:find("knife", 1, true) or lowered:find("dagger", 1, true) or lowered:find("shiv", 1, true) then
        return "ShortBlade"
    end
    if lowered:find("hammer", 1, true) or lowered:find("wrench", 1, true) or lowered:find("nightstick", 1, true) then
        return "ShortBlunt"
    end
    if lowered:find("bat", 1, true) or lowered:find("crowbar", 1, true) or lowered:find("pipe", 1, true)
        or lowered:find("rollingpin", 1, true) or lowered:find("shovel", 1, true)
    then
        return "LongBlunt"
    end
    return "Strength"
end

function Skills.BuildSnapshot(record)
    local levels = {}
    local skillIDs = Catalog.GetAllSkillIDs()
    local i
    for i = 1, #skillIDs do
        levels[skillIDs[i]] = Skills.GetLevel(record, skillIDs[i])
    end
    return levels
end
