PNC = PNC or {}
PNC.ZombieAggro = PNC.ZombieAggro or {}

local ZombieAggro = PNC.ZombieAggro
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry

ZombieAggro.State = ZombieAggro.State or {
    bites = {},
}
ZombieAggro.Internal = ZombieAggro.Internal or {}

local Internal = ZombieAggro.Internal

function Internal.ensureZombieID(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return nil
    end
    modData = zombie:getModData()
    if not modData then
        return nil
    end
    if not modData.PNC_ZombieID or tostring(modData.PNC_ZombieID) == "" then
        modData.PNC_ZombieID = Core.GenerateID("pz")
    end
    return modData.PNC_ZombieID
end

function Internal.getZombieModData(zombie)
    return zombie and zombie.getModData and zombie:getModData() or nil
end

function Internal.isManagedNPCBody(zombie)
    local modData = Internal.getZombieModData(zombie)
    return modData and modData.PNC_NPC == true
end

function Internal.clearZombieTarget(zombie)
    if not zombie then
        return
    end
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
    if zombie.setAttackedBy then
        zombie:setAttackedBy(nil)
    end
    if zombie.setVariable then
        zombie:setVariable("NoLungeAttack", false)
    end
end

function Internal.isCloseLivePlayerTarget(zombie, target)
    local dx
    local dy
    if not zombie or not target or not instanceof or not instanceof(target, "IsoPlayer") then
        return false
    end
    dx = target:getX() - zombie:getX()
    dy = target:getY() - zombie:getY()
    return ((dx * dx) + (dy * dy)) <= (Const.ZOMBIE_TARGET_PLAYER_KEEP_RADIUS * Const.ZOMBIE_TARGET_PLAYER_KEEP_RADIUS)
end

function Internal.findNearestLiveNPC(zombie, radius)
    local bestRecord
    local bestBody
    local bestDistSq
    local zx
    local zy
    local zz
    local limitSq

    if not zombie then
        return nil, nil, math.huge
    end

    zx = zombie:getX()
    zy = zombie:getY()
    zz = zombie:getZ()
    limitSq = radius * radius
    bestDistSq = math.huge

    Registry.ForEachLive(function(record, npcBody)
        local distSq
        if npcBody
            and record
            and record.alive ~= false
            and record.presenceState == Const.PRESENCE_LIVE
            and math.abs(npcBody:getZ() - zz) < 1
        then
            distSq = Core.DistanceSq(zx, zy, npcBody:getX(), npcBody:getY())
            if distSq <= limitSq and distSq < bestDistSq then
                bestRecord = record
                bestBody = npcBody
                bestDistSq = distSq
            end
        end
    end)

    return bestRecord, bestBody, bestDistSq
end

function Internal.canZombieAttack(zombie, now)
    local modData = Internal.getZombieModData(zombie)
    local lastAttackAt
    if not modData then
        return false
    end
    lastAttackAt = tonumber(modData.PNC_LastAttackAt or 0) or 0
    if (now - lastAttackAt) < Const.ZOMBIE_ATTACK_COOLDOWN_MS then
        return false
    end
    modData.PNC_LastAttackAt = now
    return true
end

function Internal.forceAggro(zombie, npcBody)
    if zombie.spotted then
        zombie:spotted(npcBody, true)
    end
    if zombie.addAggro then
        zombie:addAggro(npcBody, 1)
    end
    if zombie.setTarget then
        zombie:setTarget(npcBody)
    end
    if zombie.setAttackedBy then
        zombie:setAttackedBy(npcBody)
    end
end
