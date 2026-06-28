--[[
    PNC Behavior Incapacitated
    Handles the downed grace-period state so the main behavior coordinator does
    not mix crawl, shove, and revive-hold logic with normal jobs.
]]

PNC = PNC or {}
PNC.BehaviorIncapacitated = PNC.BehaviorIncapacitated or {}

local Incapacitated = PNC.BehaviorIncapacitated
local Core = PNC.Core
local Const = PNC.Const
local Combat = PNC.Combat
local Perception = PNC.Perception
local Animation = PNC.Animation
local Common = PNC.BehaviorCommon

function Incapacitated.Tick(record, zombie)
    local owner
    local ownerDist
    local target

    record.activeJob = "Incapacitated"
    record.activeBehavior = "Incapacitated"
    target = Perception.FindNearestEnemyZombie(record, Const.INCAP_SHOVE_RANGE + 0.2)
    if target then
        record.runtime.target = target
        if Combat.TryDownedShove and Combat.TryDownedShove(record, zombie, target) then
            Common.SetCombatDebug(record, target, "downed_shove", "melee", "downed_shove")
        else
            Common.SetCombatDebug(record, target, "downed_under_pressure", "melee", "downed_shove")
        end
        return true
    end

    owner = Common.GetOwner(record)
    Common.ClearCombatTarget(record, "incapacitated")
    if zombie and owner and record.orderSpec and record.orderSpec.kind == Const.ORDER_FOLLOW then
        ownerDist = Core.Distance(record.x, record.y, owner:getX(), owner:getY())
        if ownerDist > (Const.FOLLOW_DISTANCE + 0.5) then
            Common.MoveRecord(record, zombie, owner:getX(), owner:getY(), owner:getZ(), "crawl", 1.2)
        else
            Common.HaltMovement(record, zombie, "incap_hold")
            if Animation and Animation.ApplyDowned then
                Animation.ApplyDowned(zombie, record, false)
            end
        end
    elseif zombie then
        Common.HaltMovement(record, zombie, "incap_hold")
        if Animation and Animation.ApplyDowned then
            Animation.ApplyDowned(zombie, record, false)
        else
            Animation.Apply(zombie, record, "Crawl")
        end
    end
    return true
end
