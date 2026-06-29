--[[
    PNC Behavior Companion
    Owns companion job handlers such as follow, guard, and patrol so those
    rules stay isolated from hostile roaming and combat internals.
]]

PNC = PNC or {}
PNC.BehaviorCompanion = PNC.BehaviorCompanion or {}

local Companion = PNC.BehaviorCompanion
local Core = PNC.Core
local Const = PNC.Const
local Stealth = PNC.Stealth
local Animation = PNC.Animation
local Common = PNC.BehaviorCommon
local Targeting = PNC.BehaviorTargeting
local BehaviorCombat = PNC.BehaviorCombat

function Companion.Tick(record, zombie, job)
    local owner
    local ownerDist
    local target
    local patrolPoints
    local point
    local moveMode
    local order = record.orderSpec or {}

    if job == "FollowOwner" then
        owner = Common.GetOwner(record)
        if Stealth and Stealth.UpdateFollowState then
            Stealth.UpdateFollowState(record, owner)
        end
        target = Targeting.ResolveCompanionEngageTarget(record)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        if owner then
            record.ownerUsername = owner:getUsername()
            record.ownerOnlineID = owner:getOnlineID()
            ownerDist = Core.Distance(record.x, record.y, owner:getX(), owner:getY())
            if ownerDist <= Const.FOLLOW_DISTANCE and math.abs(owner:getZ() - record.z) < 1 then
                Common.ClearCombatTarget(record, record.runtime.stealthActive and "holding_follow_stealth" or "holding_follow_position")
                if zombie then
                    Common.HaltMovement(record, zombie, "follow_hold")
                    Animation.Apply(zombie, record, "Idle")
                end
                return true
            end
            moveMode = Stealth and Stealth.ResolveFollowMoveMode and Stealth.ResolveFollowMoveMode(record, owner, ownerDist)
                or (ownerDist >= Const.FOLLOW_RUN_DISTANCE and "run" or "walk")
            Common.ClearCombatTarget(record, moveMode == "sneak" and "following_owner_sneak" or ("following_owner_" .. tostring(moveMode)))
            Common.MoveRecord(
                record,
                zombie,
                owner:getX(),
                owner:getY(),
                owner:getZ(),
                moveMode,
                Const.FOLLOW_DISTANCE,
                moveMode == "sneak" and "follow_owner_sneak" or ("follow_owner_" .. tostring(moveMode))
            )
            return true
        end
        if Stealth and Stealth.Clear then
            Stealth.Clear(record, "owner_missing")
        end
        Common.ClearCombatTarget(record, "owner_missing_return_anchor")
        Common.MoveRecord(record, zombie, record.anchorX, record.anchorY, record.anchorZ, "walk", 0.8, "owner_missing_return_anchor")
        return true
    end

    if job == "GuardAnchor" then
        target = Targeting.ResolveCompanionEngageTarget(record)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        Common.ClearCombatTarget(record, "guarding_anchor")
        Common.MoveRecord(
            record,
            zombie,
            tonumber(order.x) or record.anchorX,
            tonumber(order.y) or record.anchorY,
            tonumber(order.z) or record.anchorZ,
            "walk",
            Const.GUARD_RADIUS,
            "guard_anchor"
        )
        return true
    end

    if job == "PatrolRoute" then
        target = Targeting.ResolveCompanionEngageTarget(record)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        patrolPoints = order.points or record.patrolPoints or {}
        if #patrolPoints <= 0 then
            Common.ClearCombatTarget(record, "patrol_missing_points")
            Common.MoveRecord(record, zombie, record.anchorX, record.anchorY, record.anchorZ, "walk", 0.8, "patrol_missing_points")
            return true
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
                Common.ClearCombatTarget(record, "patrolling")
                Common.MoveRecord(record, zombie, point.x, point.y, point.z, "walk", Const.PATROL_REACHED_DISTANCE, "patrol_route")
            end
        end
        return true
    end

    return false
end
