--[[
    PNC Behavior Hostile
    Owns hostile roam, hunt, and direct engage job handlers so aggression logic
    stays separate from companion-follow rules.
]]

PNC = PNC or {}
PNC.BehaviorHostile = PNC.BehaviorHostile or {}

local Hostile = PNC.BehaviorHostile
local Core = PNC.Core
local Common = PNC.BehaviorCommon
local Targeting = PNC.BehaviorTargeting
local BehaviorCombat = PNC.BehaviorCombat

function Hostile.Tick(record, zombie, job)
    local target
    local order = record.orderSpec or {}

    if job == "HuntNearestPlayer" then
        target = Targeting.ResolveHostileEngageTarget(record)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        Common.ClearCombatTarget(record, "seeking_hostile_target")
        Common.MoveRecord(
            record,
            zombie,
            tonumber(order.x) or record.anchorX,
            tonumber(order.y) or record.anchorY,
            tonumber(order.z) or record.anchorZ,
            "walk",
            2.0
        )
        return true
    end

    if job == "RoamArea" then
        target = Targeting.ResolveHostileEngageTarget(record)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        if not record.runtime.roamGoalX or Core.Distance(record.x, record.y, record.runtime.roamGoalX, record.runtime.roamGoalY) <= 1 then
            record.runtime.roamGoalX = (tonumber(order.x) or record.anchorX) + ZombRandFloat(-6, 6)
            record.runtime.roamGoalY = (tonumber(order.y) or record.anchorY) + ZombRandFloat(-6, 6)
            record.runtime.roamGoalZ = tonumber(order.z) or record.anchorZ
        end
        Common.ClearCombatTarget(record, "roaming")
        Common.MoveRecord(record, zombie, record.runtime.roamGoalX, record.runtime.roamGoalY, record.runtime.roamGoalZ, "walk", 1.0)
        return true
    end

    if job == "EngageTarget" then
        target = Targeting.UpdateTargetFromWorld(record, record.runtime.target)
        if target then
            record.runtime.target = target
            BehaviorCombat.TickEngage(record, zombie, target)
            return true
        end
        Common.ClearCombatTarget(record, "target_lost")
        return true
    end

    return false
end
