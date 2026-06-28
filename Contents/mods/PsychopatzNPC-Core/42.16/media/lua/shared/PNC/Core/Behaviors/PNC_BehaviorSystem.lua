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
local Equipment = PNC.Equipment
local Stealth = PNC.Stealth

local function setCombatDebug(record, target, reason, modeResolved, weaponStatus)
    record.runtime.targetKind = target and target.kind or "none"
    record.runtime.combatModeResolved = modeResolved or tostring(record.weaponMode or "melee")
    record.runtime.weaponStatus = weaponStatus or record.runtime.weaponStatus or "unknown"
    record.runtime.combatBlockReason = reason or "idle"
end

local function clearCombatTarget(record, reason)
    local equipmentInfo = Equipment.Describe(record)
    record.runtime.target = nil
    setCombatDebug(
        record,
        nil,
        reason or "no_target",
        equipmentInfo.combatModeResolved or tostring(record.weaponMode or "melee"),
        equipmentInfo.weaponStatus or record.runtime.weaponStatus
    )
end

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

local function updateTargetFromWorld(record, target)
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

local function haltMovement(record, zombie)
    if zombie and PathService and PathService.Reset then
        PathService.Reset(zombie, record)
    end
end

local function tickEngage(record, zombie, target)
    local dist = math.sqrt(tonumber(target and target.distSq or 0) or 0)
    local equipmentInfo = Equipment.Describe(record)
    local effectiveMode = equipmentInfo.combatModeResolved
    local previousWeaponStatus = record.runtime.weaponStatus
    local attacked
    local reason

    bindLiveTarget(zombie, target)
    setCombatDebug(record, target, "engaging_" .. tostring(target.kind or "unknown"), effectiveMode, equipmentInfo.weaponStatus)

    if equipmentInfo.weaponStatus ~= previousWeaponStatus then
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " weapon state=" .. tostring(equipmentInfo.weaponStatus))
    end

    if zombie then
        if dist <= Const.MELEE_RANGE * 1.1 then
            haltMovement(record, zombie)
            PNC.Animation.Apply(zombie, record, "Idle")
        else
            PNC.Animation.Apply(zombie, record, dist > Const.MELEE_RANGE and "Run" or "Walk")
        end
    end

    if effectiveMode == "melee" then
        attacked, reason = Combat.TryMelee(record, zombie, target)
        if attacked then
            haltMovement(record, zombie)
            setCombatDebug(record, target, "attacking_melee", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if reason == "target_out_of_range" then
            moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.MELEE_RANGE)
            setCombatDebug(record, target, "closing_to_melee", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        setCombatDebug(record, target, reason, effectiveMode, equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " melee blocked=" .. tostring(reason))
        return
    end

    if effectiveMode == "ranged" then
        attacked, reason = Combat.TryRanged(record, zombie, target)
        if attacked then
            haltMovement(record, zombie)
            setCombatDebug(record, target, "attacking_ranged", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        if reason == "target_out_of_range" then
            moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.RANGED_RANGE * 0.8)
            setCombatDebug(record, target, "closing_to_range", effectiveMode, equipmentInfo.weaponStatus)
            return
        end
        setCombatDebug(record, target, reason, effectiveMode, equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " ranged blocked=" .. tostring(reason))
        return
    end

    if dist <= Const.MELEE_RANGE * 1.1 then
        attacked, reason = Combat.TryMelee(record, zombie, target)
        if attacked then
            haltMovement(record, zombie)
            setCombatDebug(record, target, "attacking_melee", "mixed", equipmentInfo.weaponStatus)
            return
        end
        setCombatDebug(record, target, reason, "mixed", equipmentInfo.weaponStatus)
        Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " mixed melee blocked=" .. tostring(reason))
        return
    end

    attacked, reason = Combat.TryRanged(record, zombie, target)
    if attacked then
        haltMovement(record, zombie)
        setCombatDebug(record, target, "attacking_ranged", "mixed", equipmentInfo.weaponStatus)
        return
    end
    if reason == "target_out_of_range" then
        moveRecord(record, zombie, target.x, target.y, target.z, "run", Const.RANGED_RANGE * 0.85)
        setCombatDebug(record, target, "closing_to_range", "mixed", equipmentInfo.weaponStatus)
        return
    end
    setCombatDebug(record, target, reason, "mixed", equipmentInfo.weaponStatus)
    Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " mixed ranged blocked=" .. tostring(reason))
end

function Behavior.Tick(record, zombie, now)
    local order = record.orderSpec or {}
    local job = JobSystem.Select(record)
    local owner
    local point
    local target
    local patrolPoints
    local ownerDist
    local moveMode

    if record.alive == false then
        record.activeJob = "Dead"
        record.activeBehavior = "Dead"
        clearCombatTarget(record, "dead")
        if zombie then
            PNC.Animation.Apply(zombie, record, "Idle")
        end
        return
    end

    if record.health and record.health.state == "incapacitated" then
        record.activeJob = "Incapacitated"
        record.activeBehavior = "Incapacitated"
        target = Perception.FindNearestEnemyZombie(record, Const.INCAP_SHOVE_RANGE + 0.2)
        if target then
            record.runtime.target = target
            if Combat.TryDownedShove and Combat.TryDownedShove(record, zombie, target) then
                setCombatDebug(record, target, "downed_shove", "melee", "downed_shove")
            else
                setCombatDebug(record, target, "downed_under_pressure", "melee", "downed_shove")
            end
            return
        end
        owner = getOwner(record)
        clearCombatTarget(record, "incapacitated")
        if zombie and owner and record.orderSpec and record.orderSpec.kind == Const.ORDER_FOLLOW then
            ownerDist = Core.Distance(record.x, record.y, owner:getX(), owner:getY())
            if ownerDist > (Const.FOLLOW_DISTANCE + 0.5) then
                moveRecord(record, zombie, owner:getX(), owner:getY(), owner:getZ(), "crawl", 1.2)
            else
                PathService.Reset(zombie, record)
                if PNC.Animation and PNC.Animation.ApplyDowned then
                    PNC.Animation.ApplyDowned(zombie, record, false)
                end
            end
        elseif zombie then
            PathService.Reset(zombie, record)
            if PNC.Animation and PNC.Animation.ApplyDowned then
                PNC.Animation.ApplyDowned(zombie, record, false)
            else
                PNC.Animation.Apply(zombie, record, "Crawl")
            end
        end
        return
    end

    record.activeJob = job
    record.activeBehavior = job

    if job == "FollowOwner" then
        owner = getOwner(record)
        if Stealth and Stealth.UpdateFollowState then
            Stealth.UpdateFollowState(record, owner)
        end
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
                clearCombatTarget(record, record.runtime.stealthActive and "holding_follow_stealth" or "holding_follow_position")
                if zombie then
                    PathService.Reset(zombie, record)
                    PNC.Animation.Apply(zombie, record, record.runtime.stealthActive and "SneakWalk" or "Idle")
                end
                return
            end
            moveMode = Stealth and Stealth.ResolveFollowMoveMode and Stealth.ResolveFollowMoveMode(record, owner, ownerDist) or (ownerDist >= Const.FOLLOW_RUN_DISTANCE and "run" or "walk")
            clearCombatTarget(record, moveMode == "sneak" and "following_owner_sneak" or ("following_owner_" .. tostring(moveMode)))
            moveRecord(record, zombie, owner:getX(), owner:getY(), owner:getZ(), moveMode, Const.FOLLOW_DISTANCE)
            return
        end
        if Stealth and Stealth.Clear then
            Stealth.Clear(record, "owner_missing")
        end
        clearCombatTarget(record, "owner_missing_return_anchor")
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
        clearCombatTarget(record, "guarding_anchor")
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
            clearCombatTarget(record, "patrol_missing_points")
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
                clearCombatTarget(record, "patrolling")
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
        clearCombatTarget(record, "seeking_hostile_target")
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
        clearCombatTarget(record, "roaming")
        moveRecord(record, zombie, record.runtime.roamGoalX, record.runtime.roamGoalY, record.runtime.roamGoalZ, "walk", 1.0)
        return
    end

    if job == "EngageTarget" then
        target = updateTargetFromWorld(record, record.runtime.target)
        if target then
            record.runtime.target = target
            tickEngage(record, zombie, target)
            return
        end
        clearCombatTarget(record, "target_lost")
        return
    end
end
