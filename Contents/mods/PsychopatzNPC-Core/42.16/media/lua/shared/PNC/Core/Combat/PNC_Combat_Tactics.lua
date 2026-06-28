--[[
    PNC Combat Tactics
    Owns short-range repositioning and conservative kiting rules so melee and
    ranged NPCs can create space without becoming fully evasive.
]]

PNC = PNC or {}
PNC.CombatTactics = PNC.CombatTactics or {}

local Tactics = PNC.CombatTactics
local Core = PNC.Core
local PathService = PNC.PathService
local Perception = PNC.Perception
local Skills = PNC.Skills

local function buildRetreatPoint(record, target, distance)
    local dx
    local dy
    local len
    if not record or not target then
        return nil
    end
    dx = record.x - target.x
    dy = record.y - target.y
    len = math.sqrt((dx * dx) + (dy * dy))
    if len <= 0.001 then
        dx = 1
        dy = 0
        len = 1
    end
    return {
        x = record.x + (dx / len) * distance,
        y = record.y + (dy / len) * distance,
        z = target.z or record.z,
    }
end

function Tactics.TryReposition(record, zombie, target, effectiveMode, reason, equipmentInfo)
    local nearbyCount
    local retreat
    local aiming
    local meleeSkill
    local dist

    if not record or not zombie or not target or not PathService or not PathService.MoveToward then
        return false, nil
    end

    dist = math.sqrt(tonumber(target.distSq or 0) or 0)
    nearbyCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, 2.6) or 0

    if effectiveMode == "ranged" or effectiveMode == "mixed" then
        aiming = Skills and Skills.GetLevel and Skills.GetLevel(record, "Aiming") or 0
        if target.kind == "zombie" and (dist < 4.2 or (reason == "cooldown_active" and nearbyCount >= 1)) then
            retreat = buildRetreatPoint(record, target, 1.4 + math.min(aiming, 6) * 0.12)
            if retreat then
                PathService.MoveToward(record, zombie, retreat.x, retreat.y, retreat.z, "walk", 0.25)
                return true, "maintaining_range"
            end
        end
        return false, nil
    end

    meleeSkill = Skills and Skills.GetLevel and Skills.GetLevel(record, equipmentInfo and equipmentInfo.primaryType == "barehand" and "Strength"
        or (Skills.ResolveWeaponSkill and Skills.ResolveWeaponSkill(record, record.equipment and record.equipment.primaryFullType, "melee") or "Strength")) or 0
    if target.kind == "zombie" and (reason == "cooldown_active" or reason == "stamina_exhausted") and nearbyCount >= 2 then
        retreat = buildRetreatPoint(record, target, 0.75 + math.min(meleeSkill, 6) * 0.08)
        if retreat then
            PathService.MoveToward(record, zombie, retreat.x, retreat.y, retreat.z, "walk", 0.2)
            return true, "melee_kiting"
        end
    end

    return false, nil
end
