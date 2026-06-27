PNC = PNC or {}
PNC.Presence = PNC.Presence or {}

local Presence = PNC.Presence
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Health = PNC.Health
local Animation = PNC.Animation
local Visuals = PNC.Visuals
local Equipment = PNC.Equipment
local PathService = PNC.PathService
local Network = nil

local function resolveNetwork()
    if not Network then
        Network = PNC.Network
    end
    return Network
end

local function findMaterializeSquare(record)
    local cell
    local x
    local y
    local z
    local dx
    local dy
    local square

    if not getCell then
        return record.x, record.y, record.z
    end

    cell = getCell()
    x = math.floor(record.x)
    y = math.floor(record.y)
    z = math.floor(record.z)

    for dx = -2, 2 do
        for dy = -2, 2 do
            square = cell:getGridSquare(x + dx, y + dy, z)
            if square and square:isFree(false) and (not square:isSolid()) and (not square:isSolidTrans()) then
                return x + dx, y + dy, z
            end
        end
    end
    return x, y, z
end

function Presence.ShouldMaterialize(record)
    local nearest = Core.GetNearestPlayerPosition(record.x, record.y)
    if record.alive == false or record.presenceState == Const.PRESENCE_CORPSE then
        return false
    end
    if record.runtime and record.runtime.forceAbstract then
        return false
    end
    if record.runtime and record.runtime.forceLive then
        return true
    end
    return nearest and nearest.distSq <= (Const.MATERIALIZE_DISTANCE * Const.MATERIALIZE_DISTANCE) or false
end

function Presence.ShouldAbstract(record)
    local nearest = Core.GetNearestPlayerPosition(record.x, record.y)
    if record.presenceState ~= Const.PRESENCE_LIVE then
        return false
    end
    if record.runtime and record.runtime.forceLive then
        return false
    end
    if record.runtime and record.runtime.forceAbstract then
        return true
    end
    if record.runtime and record.runtime.target then
        return false
    end
    return (not nearest) or nearest.distSq >= (Const.ABSTRACT_DISTANCE * Const.ABSTRACT_DISTANCE)
end

function Presence.Materialize(record, reason)
    local zombieList
    local zombie
    local spawnX
    local spawnY
    local spawnZ
    local net = resolveNetwork()
    if not Core.IsAuthority() or record.alive == false or record.presenceState == Const.PRESENCE_LIVE then
        return Registry.GetLiveZombie(record.id)
    end

    spawnX, spawnY, spawnZ = findMaterializeSquare(record)
    zombieList = addZombiesInOutfit(
        spawnX,
        spawnY,
        spawnZ,
        1,
        PNC.VisualProfiles.ResolveSpawnOutfit(record),
        record.isFemale and 100 or 0,
        false,
        false,
        false,
        false,
        true,
        false,
        1
    )

    if not zombieList or zombieList:size() <= 0 then
        Core.LogWarn("Failed to materialize NPC " .. tostring(record.id) .. " reason=" .. tostring(reason))
        return nil
    end

    zombie = zombieList:get(0)
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if zombie.DoZombieStats then
        zombie:DoZombieStats()
    end
    Animation.ApplyLiveSetup(zombie, record)
    Visuals.ApplyHumanVisuals(zombie, record)
    Equipment.Apply(zombie, record)

    record.x = spawnX
    record.y = spawnY
    record.z = spawnZ
    record.presenceState = Const.PRESENCE_LIVE
    record.runtime.target = nil
    Registry.RegisterLiveZombie(record, zombie)
    Health.Update(record, zombie, Core.Now())
    Animation.Apply(zombie, record, "Idle")

    if net and net.BroadcastRecord then
        net.BroadcastRecord(record, "materialize")
    end

    return zombie
end

function Presence.Abstract(record, reason)
    local zombie = Registry.GetLiveZombie(record.id)
    local net = resolveNetwork()
    if not Core.IsAuthority() or record.presenceState ~= Const.PRESENCE_LIVE then
        return false
    end

    record.runtime.target = nil
    record.runtime.lastPathX = nil
    record.runtime.lastPathY = nil
    record.runtime.roamGoalX = nil
    record.runtime.roamGoalY = nil

    if zombie then
        record.x = zombie:getX()
        record.y = zombie:getY()
        record.z = zombie:getZ()
        PathService.Reset(zombie, record)
        if zombie.removeFromWorld then
            zombie:removeFromWorld()
        end
        if zombie.removeFromSquare then
            zombie:removeFromSquare()
        end
        Registry.UnregisterLiveZombie(record.id)
    end

    record.presenceState = Const.PRESENCE_ABSTRACT
    if net and net.BroadcastRemoval then
        net.BroadcastRemoval(record.id, reason or "abstract")
    end
    return true
end

function Presence.Reconcile(record)
    if record.alive == false then
        return
    end
    if Presence.ShouldMaterialize(record) then
        Presence.Materialize(record, "range_enter")
    elseif Presence.ShouldAbstract(record) then
        Presence.Abstract(record, "range_exit")
    end
end
