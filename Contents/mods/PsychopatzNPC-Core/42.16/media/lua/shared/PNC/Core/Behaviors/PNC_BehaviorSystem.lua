PNC = PNC or {}
PNC.BehaviorSystem = PNC.BehaviorSystem or {}

local Behavior = PNC.BehaviorSystem
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Perception = PNC.Perception
local Combat = PNC.Combat
local PathService = PNC.PathService
local JobSystem = PNC.JobSystem

local function bindLiveTarget(zombie, target)
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
        if targetZombie then
            if zombie.faceThisObject then
                zombie:faceThisObject(targetZombie)
            elseif zombie.faceLocationF then
                zombie:faceLocationF(target.x, target.y)
            end
        end
    end
end

local function getOwner(record)
    return Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
end

local function moveRecord(record, zombie, tx, ty, tz, mode, stopDistance)
    if record.presenceState == Const.PRESENCE_LIVE then
        return PathService.MoveToward(record, zombie, tx, ty, tz, mode, stopDistance)
    end
    PathService.AdvanceAbstract(record, tx, ty, tz, stopDistance)
    return true, "abstract_move"
end

local function tickEngage(record, zombie, target)
    local dist = math.sqrt(tonumber(target and target.distSq or 0) or 0)
    local weaponMode = tostring(record.weaponMode or "melee")
    bindLiveTarget(zombie, target)
    if zombie then
        PNC.Animation.Apply(zombie, record, dist > Const.MELEE_RANGE and "Run" or "Walk")
    end

    if weaponMode == "melee" then
        if not Combat.TryMelee(record, zombie, target) then
            moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.MELEE_RANGE)
        end
        return
    end

    if weaponMode == "ranged" then
        if not Combat.TryRanged(record, zombie, target) then
            if dist > Const.RANGED_RANGE then
                moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.RANGED_RANGE * 0.8)
            end
        end
        return
    end

    if dist <= Const.MELEE_RANGE * 1.1 then
        Combat.TryMelee(record, zombie, target)
    else
        if not Combat.TryRanged(record, zombie, target) then
            moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.RANGED_RANGE * 0.85)
        end
    end
end

function Behavior.Tick(record, zombie, now)
    local order = record.orderSpec or {}
    local job = JobSystem.Select(record)
    local owner
    local point
    local target
    local patrolPoints
    local ownerDist

    record.activeJob = job
    record.activeBehavior = job

    if job == "FollowOwner" then
        owner = getOwner(record)
        target = Perception.ResolveCompanionTarget(record)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        if owner then
            record.ownerUsername = owner:getUsername()
            record.ownerOnlineID = owner:getOnlineID()
            ownerDist = Core.Distance(record.x, record.y, owner:getX(), owner:getY())
            if ownerDist <= Const.FOLLOW_DISTANCE and math.abs(owner:getZ() - record.z) < 1 then
                if zombie then
                    PNC.Animation.Apply(zombie, record, "Idle")
                end
                return
            end
            if ownerDist >= Const.FOLLOW_RUN_DISTANCE then
                moveRecord(record, zombie, owner:getX(), owner:getY(), owner:getZ(), "run", Const.FOLLOW_DISTANCE)
                return
            end
            moveRecord(record, zombie, owner:getX(), owner:getY(), owner:getZ(), "walk", Const.FOLLOW_DISTANCE)
            return
        end
        moveRecord(record, zombie, record.anchorX, record.anchorY, record.anchorZ, "walk", 0.8)
        return
    end

    if job == "GuardAnchor" then
        target = Perception.ResolveCompanionTarget(record)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        moveRecord(record, zombie, tonumber(order.x) or record.anchorX, tonumber(order.y) or record.anchorY, tonumber(order.z) or record.anchorZ, "walk", Const.GUARD_RADIUS)
        return
    end

    if job == "PatrolRoute" then
        target = Perception.ResolveCompanionTarget(record)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        patrolPoints = order.points or record.patrolPoints or {}
        if #patrolPoints <= 0 then
            moveRecord(record, zombie, record.anchorX, record.anchorY, record.anchorZ, "walk", 0.8)
            return
        end
        record.patrolIndex = record.patrolIndex or 1
        point = patrolPoints[record.patrolIndex]
        if point then
            if Core.Distance(record.x, record.y, point.x, point.y) <= Const.PATROL_REACHED_DISTANCE then
                record.patrolIndex = record.patrolIndex + 1
                if record.patrolIndex > #patrolPoints then
                    record.patrolIndex = 1
                end
                point = patrolPoints[record.patrolIndex]
            end
            if point then
                moveRecord(record, zombie, point.x, point.y, point.z, "walk", Const.PATROL_REACHED_DISTANCE)
            end
        end
        return
    end

    if job == "HuntNearestPlayer" then
        target = Perception.ResolveHostileTarget(record)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        moveRecord(record, zombie, tonumber(order.x) or record.anchorX, tonumber(order.y) or record.anchorY, tonumber(order.z) or record.anchorZ, "walk", 2.0)
        return
    end

    if job == "RoamArea" then
        target = Perception.ResolveHostileTarget(record)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        if not record.runtime.roamGoalX or Core.Distance(record.x, record.y, record.runtime.roamGoalX, record.runtime.roamGoalY) <= 1 then
            record.runtime.roamGoalX = (tonumber(order.x) or record.anchorX) + ZombRandFloat(-6, 6)
            record.runtime.roamGoalY = (tonumber(order.y) or record.anchorY) + ZombRandFloat(-6, 6)
            record.runtime.roamGoalZ = tonumber(order.z) or record.anchorZ
        end
        moveRecord(record, zombie, record.runtime.roamGoalX, record.runtime.roamGoalY, record.runtime.roamGoalZ, "walk", 1.0)
        return
    end

    if job == "EngageTarget" then
        target = record.runtime.target
        if target and target.kind == "npc" then
            local targetRecord = Registry.Get(target.id)
            if targetRecord and targetRecord.alive ~= false then
                target.x = targetRecord.x
                target.y = targetRecord.y
                target.z = targetRecord.z
                target.distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
                tickEngage(record, zombie, target)
                return
            end
        elseif target and target.kind == "player" then
            target.player = Core.ResolvePlayerByOnlineID(target.onlineID) or Core.ResolvePlayerByUsername(target.username)
            if target.player then
                target.x = target.player:getX()
                target.y = target.player:getY()
                target.z = target.player:getZ()
                target.distSq = Core.DistanceSq(record.x, record.y, target.x, target.y)
                tickEngage(record, zombie, target)
                return
            end
        end
        record.runtime.target = nil
        return
    end
end
