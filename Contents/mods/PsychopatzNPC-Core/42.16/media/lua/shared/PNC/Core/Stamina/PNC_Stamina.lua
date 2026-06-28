PNC = PNC or {}
PNC.Stamina = PNC.Stamina or {}

local Stamina = PNC.Stamina
local Core = PNC.Core
local Const = PNC.Const
local Skills = PNC.Skills

local function clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or minValue
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

local function ensureState(record)
    local averageCombat
    local endurance
    local strength
    local resolvedMax
    local current
    if not record then
        return nil
    end
    averageCombat = Skills.GetAverage(record, { "Axe", "LongBlade", "LongBlunt", "ShortBlade", "ShortBlunt", "Spear", "Aiming" })
    endurance = Skills.GetLevel(record, "Fitness")
    strength = Skills.GetLevel(record, "Strength")
    resolvedMax = math.floor(100 + ((averageCombat + endurance + strength) * 2.5))
    record.stamina = record.stamina or {}
    current = tonumber(record.stamina.current)
    if current == nil then
        current = resolvedMax
    elseif tonumber(record.stamina.max) and tonumber(record.stamina.max) > 0 and tonumber(record.stamina.max) ~= resolvedMax then
        current = (current / tonumber(record.stamina.max)) * resolvedMax
    end
    record.stamina.max = resolvedMax
    record.stamina.current = clamp(current, 0, resolvedMax)
    record.stamina.state = record.stamina.state or "fresh"
    record.stamina.visibleUntil = tonumber(record.stamina.visibleUntil) or 0
    record.stamina.lastUpdatedAt = tonumber(record.stamina.lastUpdatedAt) or Core.Now()
    return record.stamina
end

local function updateState(record)
    local stamina = ensureState(record)
    local ratio
    if not stamina then
        return nil
    end
    ratio = Stamina.GetRatio(record)
    if ratio <= 0.15 then
        stamina.state = "exhausted"
    elseif ratio <= 0.4 then
        stamina.state = "winded"
    elseif ratio <= 0.7 then
        stamina.state = "working"
    else
        stamina.state = "fresh"
    end
    return stamina
end

function Stamina.GetRatio(record)
    local stamina = ensureState(record)
    if not stamina then
        return 1
    end
    return clamp((tonumber(stamina.current) or tonumber(stamina.max) or 1) / math.max(1, tonumber(stamina.max) or 1), 0, 1)
end

function Stamina.GetAttackDrain(record, attackType, skillID)
    local baseCost
    local skillLevel
    local normalized
    if tostring(attackType or "") == "ranged" then
        baseCost = Const.STAMINA_RANGED_COST
    elseif tostring(attackType or "") == "downed_shove" then
        baseCost = Const.STAMINA_DOWNED_SHOVE_COST
    else
        baseCost = Const.STAMINA_MELEE_COST
    end
    skillLevel = Skills.GetLevel(record, skillID or "Strength")
    normalized = clamp(skillLevel / 10, 0, 1)
    return math.max(1, baseCost * (1 - (normalized * 0.65)))
end

function Stamina.CanSpendAttack(record, attackType, skillID)
    local stamina = ensureState(record)
    local drain
    if not stamina then
        return false
    end
    drain = Stamina.GetAttackDrain(record, attackType, skillID)
    return (tonumber(stamina.current) or 0) >= math.min(drain, Const.STAMINA_ATTACK_MIN_RESERVE)
end

function Stamina.SpendAttack(record, attackType, skillID)
    local stamina = ensureState(record)
    local drain
    if not stamina then
        return false
    end
    drain = Stamina.GetAttackDrain(record, attackType, skillID)
    stamina.current = clamp((tonumber(stamina.current) or 0) - drain, 0, tonumber(stamina.max) or 100)
    stamina.visibleUntil = Core.Now() + Const.STAMINA_VISIBLE_MS
    updateState(record)
    return true
end

function Stamina.Update(record, zombie, now)
    local stamina = ensureState(record)
    local lastUpdatedAt
    local elapsed
    local recoverRate
    if not stamina then
        return
    end
    now = tonumber(now) or Core.Now()
    lastUpdatedAt = tonumber(stamina.lastUpdatedAt) or now
    elapsed = math.max(0, now - lastUpdatedAt) / 1000
    stamina.lastUpdatedAt = now
    if elapsed <= 0 then
        return
    end

    recoverRate = Const.STAMINA_RECOVERY_IDLE
    if record.runtime and record.runtime.target then
        recoverRate = Const.STAMINA_RECOVERY_COMBAT
    end
    if record.health and record.health.state == "incapacitated" then
        recoverRate = Const.STAMINA_RECOVERY_DOWNED
    end
    if record.runtime and record.runtime.pathing and record.runtime.pathing.goalX ~= nil and record.runtime.pathing.finished ~= true then
        recoverRate = math.min(recoverRate, Const.STAMINA_RECOVERY_MOVING)
    end
    if zombie and zombie.isRunning and zombie:isRunning() then
        recoverRate = Const.STAMINA_RECOVERY_MOVING
    end

    stamina.current = clamp((tonumber(stamina.current) or 0) + (recoverRate * elapsed), 0, tonumber(stamina.max) or 100)
    updateState(record)
end

function Stamina.BuildSnapshot(record)
    local stamina = ensureState(record)
    return {
        current = stamina and stamina.current or 0,
        max = stamina and stamina.max or 100,
        state = stamina and stamina.state or "fresh",
        visibleUntil = stamina and stamina.visibleUntil or 0,
    }
end
