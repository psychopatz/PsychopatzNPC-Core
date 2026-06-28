--[[
    PNC Behavior Targeting
    Shared target refresh and live-body facing helpers used by companion and
    hostile behavior branches.
]]

PNC = PNC or {}
PNC.BehaviorTargeting = PNC.BehaviorTargeting or {}

local Targeting = PNC.BehaviorTargeting
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Perception = PNC.Perception

function Targeting.BindLiveTarget(zombie, target)
    local targetZombie
    if not zombie or not target then
        return
    end
    if target.kind == "player" and target.player then
        if zombie.faceThisObject then
            zombie:faceThisObject(target.player)
        elseif zombie.faceLocationF then
            zombie:faceLocationF(target.x, target.y)
        end
        return
    end
    if target.kind == "npc" then
        targetZombie = Registry.GetLiveZombie(target.id)
    elseif target.kind == "zombie" and Perception.FindZombieByID then
        targetZombie = Perception.FindZombieByID(target.zombieId)
    end
    if targetZombie then
        if zombie.faceThisObject then
            zombie:faceThisObject(targetZombie)
        elseif zombie.faceLocationF then
            zombie:faceLocationF(target.x, target.y)
        end
    end
end

function Targeting.UpdateTargetFromWorld(record, target)
    local targetRecord
    local player
    local zombie
    if not target then
        return nil
    end
    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord and targetRecord.alive ~= false then
            target.x = targetRecord.x
            target.y = targetRecord.y
            target.z = targetRecord.z
            target.distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
            return target
        end
        return nil
    end
    if target.kind == "player" then
        player = Core.ResolvePlayerByOnlineID(target.onlineID) or Core.ResolvePlayerByUsername(target.username)
        if player then
            target.player = player
            target.x = player:getX()
            target.y = player:getY()
            target.z = player:getZ()
            target.distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
            return target
        end
        return nil
    end
    if target.kind == "zombie" then
        zombie = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if zombie then
            target.x = zombie:getX()
            target.y = zombie:getY()
            target.z = zombie:getZ()
            target.distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
            return target
        end
        return Perception.FindNearestEnemyZombie(record, Const.ZOMBIE_TARGET_RADIUS)
    end
    return nil
end

function Targeting.ResolveCompanionEngageTarget(record)
    local target = Targeting.UpdateTargetFromWorld(record, record.runtime and record.runtime.target or nil)
    if target then
        return target
    end
    return Perception.ResolveCompanionTarget(record)
end

function Targeting.ResolveHostileEngageTarget(record)
    local target = Targeting.UpdateTargetFromWorld(record, record.runtime and record.runtime.target or nil)
    if target then
        return target
    end
    return Perception.ResolveHostileTarget(record)
end
