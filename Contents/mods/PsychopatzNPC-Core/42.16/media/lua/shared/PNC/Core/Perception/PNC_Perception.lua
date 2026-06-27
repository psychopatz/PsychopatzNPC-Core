PNC = PNC or {}
PNC.Perception = PNC.Perception or {}

local Perception = PNC.Perception
local Core = PNC.Core
local Const = PNC.Const
local Spatial = PNC.SpatialIndex

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

local function ensureZombieID(zombie)
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

local function isManagedNPCBody(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return false
    end
    modData = zombie:getModData()
    return modData and modData.PNC_NPC == true
end

local function buildZombieTarget(zombie, distSq)
    local zombieId = ensureZombieID(zombie)
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
    local cell
    local zombieList
    local best
    local bestDistSq
    local i
    local zombie
    local distSq

    if not record or record.hostility and record.hostility.attackZombies == false then
        return nil
    end
    if not getCell then
        return nil
    end

    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return nil
    end

    best = nil
    bestDistSq = math.huge
    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) and math.abs(zombie:getZ() - record.z) < 1 then
            distSq = Core.DistanceSq(record.x, record.y, zombie:getX(), zombie:getY())
            if distSq <= (radius * radius) and distSq < bestDistSq then
                best = buildZombieTarget(zombie, distSq)
                bestDistSq = distSq
            end
        end
    end

    return best
end

function Perception.FindZombieByID(zombieId)
    local cell
    local zombieList
    local i
    local zombie
    if not zombieId or not getCell then
        return nil
    end
    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return nil
    end
    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and ensureZombieID(zombie) == zombieId then
            return zombie
        end
    end
    return nil
end

function Perception.ResolveCompanionTarget(record)
    local owner
    local npcTarget
    local zombieTarget
    local hostileToOwnerNPC
    local hostileToOwnerZombie

    owner = Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
    npcTarget = Perception.FindNearestEnemyNPC(record, 8)
    zombieTarget = Perception.FindNearestEnemyZombie(record, 8)
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
        }, 8)
        hostileToOwnerZombie = Perception.FindNearestEnemyZombie({
            id = record.id,
            faction = record.faction,
            x = owner:getX(),
            y = owner:getY(),
            z = owner:getZ(),
            hostility = record.hostility,
        }, 8)
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
        zombieTarget = Perception.FindNearestEnemyZombie(record, Const.ZOMBIE_TARGET_RADIUS)
    end

    return pickNearest(pickNearest(npcTarget, playerTarget), zombieTarget)
end
