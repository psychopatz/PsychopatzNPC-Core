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

function Perception.ResolveCompanionTarget(record)
    local owner
    local npcTarget
    owner = Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
    npcTarget = Perception.FindNearestEnemyNPC(record, 8)
    if npcTarget then
        return npcTarget
    end
    if owner then
        local hostileToOwner = Perception.FindNearestEnemyNPC({
            id = record.id,
            faction = record.faction,
            x = owner:getX(),
            y = owner:getY(),
            z = owner:getZ(),
        }, 8)
        if hostileToOwner then
            return hostileToOwner
        end
    end
    return nil
end

function Perception.ResolveHostileTarget(record)
    local hostileConfig = record and record.hostility or {}
    local npcTarget = nil
    local playerTarget = nil

    if hostileConfig.attackNPCs ~= false then
        npcTarget = Perception.FindNearestEnemyNPC(record, 12)
    end
    if hostileConfig.attackPlayers ~= false then
        playerTarget = Perception.FindNearestEnemyPlayer(record, 12)
    end

    return pickNearest(npcTarget, playerTarget)
end
