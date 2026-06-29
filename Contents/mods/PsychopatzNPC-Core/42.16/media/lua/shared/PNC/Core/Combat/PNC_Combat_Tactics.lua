--[[
    PNC Combat Tactics
    Owns short-range repositioning and conservative kiting rules so melee and
    ranged NPCs can create space without becoming fully evasive.
]]

PNC = PNC or {}
PNC.CombatTactics = PNC.CombatTactics or {}

local Tactics = PNC.CombatTactics
local Core = PNC.Core
local Const = PNC.Const
local PathService = PNC.PathService
local Perception = PNC.Perception
local Spatial = PNC.SpatialIndex
local Skills = PNC.Skills
local Stamina = PNC.Stamina

local function requestMove(record, zombie, x, y, z, mode, stopDistance, reason)
    local MoveIntent = PNC.BehaviorMoveIntent
    if MoveIntent and MoveIntent.RequestMove and record and record.presenceState == Const.PRESENCE_LIVE then
        MoveIntent.RequestMove(record, x, y, z, mode, stopDistance, reason)
        return true
    end
    if PathService and PathService.MoveToward then
        return PathService.MoveToward(record, zombie, x, y, z, mode, stopDistance, reason)
    end
    return false
end

local function requestCombatFacing(record, zombie, target, leaseMs, reason)
    if PathService and PathService.RequestCombatFacing then
        PathService.RequestCombatFacing(record, zombie, target, leaseMs, reason)
    end
end

local function isManagedNPCBody(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return false
    end
    modData = zombie:getModData()
    return modData and modData.PNC_NPC == true
end

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

local function countZombiesNearPoint(x, y, z, radius)
    local zombies
    local count = 0
    local i
    local zombie
    local distSq
    local radiusSq = (tonumber(radius) or 0) ^ 2
    if not Spatial or not Spatial.QueryZombies then
        return 0
    end
    zombies = Spatial.QueryZombies(x, y, tonumber(radius) or 0)
    for i = 1, #zombies do
        zombie = zombies[i]
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) and math.abs(zombie:getZ() - z) < 1 then
            distSq = Core.DistanceSq(x, y, zombie:getX(), zombie:getY())
            if distSq <= radiusSq then
                count = count + 1
            end
        end
    end
    return count
end

local function assessThreat(record, target)
    local staminaRatio = Stamina and Stamina.GetRatio and Stamina.GetRatio(record) or 1
    local runtime = record and record.runtime or {}
    local targetCrowdCount = 0
    if target and target.kind == "zombie" then
        targetCrowdCount = countZombiesNearPoint(target.x, target.y, target.z or record.z, Const.COMBAT_TARGET_CROWD_RADIUS)
    end
    return {
        staminaRatio = staminaRatio,
        retreating = runtime.retreatMode == true,
        surroundedCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, Const.COMBAT_SURROUND_RADIUS) or 0,
        pressureCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, Const.COMBAT_PRESSURE_RADIUS) or 0,
        hordeCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, Const.COMBAT_HORDE_RADIUS) or 0,
        targetCrowdCount = targetCrowdCount,
    }
end

local function setRetreatState(record, enabled, recoveryMode)
    if not record then
        return
    end
    record.runtime = record.runtime or {}
    record.runtime.retreatMode = enabled == true
    record.runtime.staminaRecoveryMode = enabled == true and recoveryMode or nil
    record.runtime.tacticalState = enabled == true and (recoveryMode or "retreat") or nil
end

function Tactics.ClearRetreatState(record)
    setRetreatState(record, false, nil)
end

function Tactics.ShouldPressureShove(record)
    local surroundedCount
    if not record then
        return false
    end
    surroundedCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, Const.COMBAT_SURROUND_RADIUS) or 0
    return surroundedCount >= Const.COMBAT_SURROUND_COUNT
end

function Tactics.TryReposition(record, zombie, target, effectiveMode, reason, equipmentInfo)
    local nearbyCount
    local retreat
    local aiming
    local meleeSkill
    local dist
    local report
    local retreatDistance
    local retreatMode
    local keepRetreating

    if not record or not zombie or not target or not PathService or not PathService.MoveToward then
        return false, nil
    end

    dist = math.sqrt(tonumber(target.distSq or 0) or 0)
    report = assessThreat(record, target)
    nearbyCount = Perception and Perception.CountEnemyZombies and Perception.CountEnemyZombies(record, 2.6) or 0

    keepRetreating = report.retreating and report.staminaRatio < Const.COMBAT_REENGAGE_STAMINA_RATIO
    if report.staminaRatio <= Const.COMBAT_RETREAT_STAMINA_RATIO or keepRetreating then
        retreatDistance = 3.8 + math.min(report.pressureCount, 4) * 0.35
        retreatMode = report.surroundedCount >= 2 and "run" or "walk"
        retreat = buildRetreatPoint(record, target, retreatDistance)
        if retreat then
            setRetreatState(record, true, "retreat")
            requestCombatFacing(record, zombie, target, 180, "retreat_facing")
            requestMove(record, zombie, retreat.x, retreat.y, retreat.z, retreatMode, 0.8, "recovering_stamina")
            return true, "recovering_stamina"
        end
    end

    if target.kind == "zombie" and (report.hordeCount >= Const.COMBAT_HORDE_COUNT or report.targetCrowdCount >= Const.COMBAT_TARGET_CROWD_COUNT) then
        retreatDistance = 2.8 + math.min(report.targetCrowdCount, 4) * 0.45
        retreatMode = report.surroundedCount >= 2 and "run" or "walk"
        retreat = buildRetreatPoint(record, target, retreatDistance)
        if retreat then
            setRetreatState(record, true, report.staminaRatio <= 0.35 and "retreat" or "avoid_horde")
            requestCombatFacing(record, zombie, target, 180, "horde_facing")
            requestMove(record, zombie, retreat.x, retreat.y, retreat.z, retreatMode, 0.8, "avoiding_horde")
            return true, "avoiding_horde"
        end
    end

    setRetreatState(record, false, nil)

    if effectiveMode == "ranged" or effectiveMode == "mixed" then
        aiming = Skills and Skills.GetLevel and Skills.GetLevel(record, "Aiming") or 0
        if target.kind == "zombie" and (dist < 4.2 or (reason == "cooldown_active" and nearbyCount >= 1)) then
            retreat = buildRetreatPoint(record, target, 1.4 + math.min(aiming, 6) * 0.12)
            if retreat then
                requestCombatFacing(record, zombie, target, 140, "range_reposition")
                requestMove(record, zombie, retreat.x, retreat.y, retreat.z, "walk", 0.25, "maintaining_range")
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
            requestCombatFacing(record, zombie, target, 120, "melee_reposition")
            requestMove(record, zombie, retreat.x, retreat.y, retreat.z, "walk", 0.2, "melee_kiting")
            return true, "melee_kiting"
        end
    end

    return false, nil
end
