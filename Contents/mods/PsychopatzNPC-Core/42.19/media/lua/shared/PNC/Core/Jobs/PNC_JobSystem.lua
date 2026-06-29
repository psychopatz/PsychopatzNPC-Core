PNC = PNC or {}
PNC.JobSystem = PNC.JobSystem or {}

local JobSystem = PNC.JobSystem
local Const = PNC.Const

function JobSystem.Select(record)
    local order = record.orderSpec or {}
    local kind = tostring(order.kind or "")

    if record.faction == "hostile" then
        if record.runtime.target then
            return "EngageTarget"
        end
        if kind == Const.ORDER_HOSTILE_ROAM then
            return "RoamArea"
        end
        return "HuntNearestPlayer"
    end

    if kind == Const.ORDER_FOLLOW then
        return "FollowOwner"
    end
    if kind == Const.ORDER_PATROL then
        return "PatrolRoute"
    end
    return "GuardAnchor"
end
