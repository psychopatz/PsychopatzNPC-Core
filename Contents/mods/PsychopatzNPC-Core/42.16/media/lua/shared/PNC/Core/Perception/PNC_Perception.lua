--[[
    PNC Perception
    Owns nearby hostile resolution, zombie target scanning, and helper queries
    used by behavior, combat, and zombie aggro bridge systems.
]]

PNC = PNC or {}
PNC.Perception = PNC.Perception or {}

local Perception = PNC.Perception
local Core = PNC.Core
local Const = PNC.Const
local Spatial = PNC.SpatialIndex
local Stealth = PNC.Stealth

local function pickNearest(firstTarget, secondTarget)
    if not firstTarget then
        return secondTarget
    end
    if not secondTarget then
        return firstTarget
    end
    if (tonumber(firstTarget.distSq) or math.huge) <= (tonumber(secondTarget.distSq) or math.huge) then
        return firstTarget
    end
    return secondTarget
end

local function isRecordEnemy(source, target)
    if not source or not target or source.id == target.id then
        return false
    end
    if source.faction == "hostile" then
        return target.faction ~= "hostile"
    end
    return target.faction == "hostile"
end

local function isManagedNPCBody(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return false
    end
    modData = zombie:getModData()
    return modData and modData.PNC_NPC == true
end

local function buildZombieTarget(zombie, distSq)
    local modData = zombie and zombie.getModData and zombie:getModData() or nil
    local zombieId = modData and modData.PNC_ZombieID or nil
    if not zombieId and Spatial and Spatial.Rebuild then
        Spatial.Rebuild()
        modData = zombie and zombie.getModData and zombie:getModData() or nil
        zombieId = modData and modData.PNC_ZombieID or nil
    end
    if not zombieId then
        return nil
    end
    return {
        kind = "zombie",
        zombieId = zombieId,
        x = zombie:getX(),
        y = zombie:getY(),
        z = zombie:getZ(),
        distSq = distSq,
    }
end

local function collectEnemyZombies(record, radius)
    local zombies
    local results = {}
    local i
    local zombie
    local distSq
    if not record or not Spatial or not Spatial.QueryZombies then
        return results
    end
    radius = tonumber(radius) or Const.ZOMBIE_TARGET_RADIUS
    zombies = Spatial.QueryZombies(record.x, record.y, radius)
    for i = 1, #zombies do
        zombie = zombies[i]
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) and math.abs(zombie:getZ() - record.z) < 1 then
            distSq = Core.DistanceSq(record.x, record.y, zombie:getX(), zombie:getY())
            if distSq <= (radius * radius) then
                results[#results + 1] = {
                    zombie = zombie,
                    distSq = distSq,
                }
            end
        end
    end
    return results
end

function Perception.FindNearestEnemyPlayer(record, radius)
    local players = Spatial.QueryPlayers(record.x, record.y, radius)
    local best = nil
    local bestDistSq = math.huge
    local i
    local player
    local distSq

    for i = 1, #players do
        player = players[i]
        if player and player:isAlive() and math.abs(player:getZ() - record.z) < 1 then
            distSq = Core.DistanceSq(record.x, record.y, player:getX(), player:getY())
            if distSq < bestDistSq then
                bestDistSq = distSq
                best = {
                    kind = "player",
                    player = player,
                    onlineID = player:getOnlineID(),
                    username = player:getUsername(),
                    x = player:getX(),
                    y = player:getY(),
                    z = player:getZ(),
                    distSq = distSq,
                }
            end
        end
    end
    return best
end

function Perception.FindNearestEnemyNPC(record, radius)
    local npcs = Spatial.QueryNPCs(record.x, record.y, radius)
    local best = nil
    local bestDistSq = math.huge
    local i
    local target
    local distSq

    for i = 1, #npcs do
        target = npcs[i]
        if target and target.alive ~= false and isRecordEnemy(record, target) and math.abs(target.z - record.z) < 1 then
            distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
            if distSq < bestDistSq then
                bestDistSq = distSq
                best = {
                    kind = "npc",
                    id = target.id,
                    x = target.x,
                    y = target.y,
                    z = target.z,
                    distSq = distSq,
                }
            end
        end
    end
    return best
end

function Perception.FindNearestEnemyZombie(record, radius)
    local zombies
    local best
    local bestDistSq
    local i
    local entry

    if not record or record.hostility and record.hostility.attackZombies == false then
        return nil
    end

    best = nil
    bestDistSq = math.huge
    zombies = collectEnemyZombies(record, radius)
    for i = 1, #zombies do
        entry = zombies[i]
        if entry and entry.distSq < bestDistSq then
            best = buildZombieTarget(entry.zombie, entry.distSq)
            bestDistSq = entry.distSq
        end
    end

    return best
end

function Perception.FindBestEnemyZombie(record, radius)
    local candidates
    local best
    local bestScore
    local i
    local j
    local entry
    local other
    local crowdCount
    local score
    local crowdRadiusSq = (tonumber(Const.COMBAT_TARGET_CROWD_RADIUS) or 2.2) ^ 2
    local crowdPenalty = 1.6

    if not record or record.hostility and record.hostility.attackZombies == false then
        return nil
    end

    candidates = collectEnemyZombies(record, radius)
    bestScore = math.huge
    for i = 1, #candidates do
        entry = candidates[i]
        if entry and entry.zombie then
            crowdCount = 0
            for j = 1, #candidates do
                other = candidates[j]
                if other and other.zombie and other.zombie ~= entry.zombie
                    and math.abs(other.zombie:getZ() - entry.zombie:getZ()) < 1
                    and Core.DistanceSq(entry.zombie:getX(), entry.zombie:getY(), other.zombie:getX(), other.zombie:getY()) <= crowdRadiusSq
                then
                    crowdCount = crowdCount + 1
                end
            end
            score = entry.distSq + (crowdCount * crowdCount * crowdPenalty)
            if score < bestScore then
                best = buildZombieTarget(entry.zombie, entry.distSq)
                bestScore = score
            end
        end
    end
    return best
end

function Perception.CountEnemyZombies(record, radius)
    local zombies
    local count = 0
    local i
    local entry

    if not record or record.hostility and record.hostility.attackZombies == false then
        return 0
    end

    zombies = collectEnemyZombies(record, radius)
    for i = 1, #zombies do
        entry = zombies[i]
        if entry then
            count = count + 1
        end
    end

    return count
end

function Perception.FindZombieByID(zombieId)
    local zombie
    if not zombieId or not Spatial or not Spatial.FindZombieByID then
        return nil
    end
    zombie = Spatial.FindZombieByID(zombieId)
    if zombie then
        return zombie
    end
    if Spatial.Rebuild then
        Spatial.Rebuild()
        return Spatial.FindZombieByID(zombieId)
    end
    return nil
end

local function getCompanionDefenseRadius()
    return math.max(8, tonumber(Const.ZOMBIE_TARGET_RADIUS) or 12)
end

function Perception.ResolveCompanionTarget(record)
    local owner
    local npcTarget
    local zombieTarget
    local hostileToOwnerNPC
    local hostileToOwnerZombie
    local defenseRadius = getCompanionDefenseRadius()

    if Stealth and Stealth.ShouldSuppressCompanionCombat and Stealth.ShouldSuppressCompanionCombat(record) then
        record.runtime = record.runtime or {}
        record.runtime.targetKind = "none"
        record.runtime.combatBlockReason = "follow_stealth_hidden"
        return nil
    end

    owner = Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
    npcTarget = Perception.FindNearestEnemyNPC(record, defenseRadius)
    zombieTarget = Perception.FindBestEnemyZombie(record, defenseRadius)
    if npcTarget or zombieTarget then
        return pickNearest(npcTarget, zombieTarget)
    end

    if owner then
        hostileToOwnerNPC = Perception.FindNearestEnemyNPC({
            id = record.id,
            faction = record.faction,
            x = owner:getX(),
            y = owner:getY(),
            z = owner:getZ(),
            hostility = record.hostility,
        }, defenseRadius)
        hostileToOwnerZombie = Perception.FindBestEnemyZombie({
            id = record.id,
            faction = record.faction,
            x = owner:getX(),
            y = owner:getY(),
            z = owner:getZ(),
            hostility = record.hostility,
        }, defenseRadius)
        return pickNearest(hostileToOwnerNPC, hostileToOwnerZombie)
    end

    return nil
end

function Perception.ResolveHostileTarget(record)
    local hostileConfig = record and record.hostility or {}
    local npcTarget = nil
    local playerTarget = nil
    local zombieTarget = nil

    if hostileConfig.attackNPCs ~= false then
        npcTarget = Perception.FindNearestEnemyNPC(record, 12)
    end
    if hostileConfig.attackPlayers ~= false then
        playerTarget = Perception.FindNearestEnemyPlayer(record, 12)
    end
    if hostileConfig.attackZombies ~= false then
        zombieTarget = Perception.FindBestEnemyZombie(record, Const.ZOMBIE_TARGET_RADIUS)
    end

    return pickNearest(pickNearest(npcTarget, playerTarget), zombieTarget)
end
