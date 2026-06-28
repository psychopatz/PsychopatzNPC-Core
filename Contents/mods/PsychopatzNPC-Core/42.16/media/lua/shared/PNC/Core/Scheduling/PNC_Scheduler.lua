PNC = PNC or {}
PNC.Scheduler = PNC.Scheduler or {}

local Scheduler = PNC.Scheduler
local Const = PNC.Const

function Scheduler.GetCadence(record)
    if record.presenceState == Const.PRESENCE_ABSTRACT then
        return Const.TICK_ABSTRACT_MS
    end
    if record.runtime and record.runtime.attackAction then
        return 50
    end
    if record.runtime and record.runtime.target then
        return math.min(Const.TICK_LIVE_HOT_MS, 75)
    end
    if record.runtime and record.runtime.pathing and (record.runtime.pathing.phase == "requested" or record.runtime.pathing.phase == "active") then
        return math.min(Const.TICK_LIVE_WARM_MS, 100)
    end
    if tostring(record.activeJob or "") == "PatrolRoute" or tostring(record.activeJob or "") == "FollowOwner" then
        return math.min(Const.TICK_LIVE_WARM_MS, 100)
    end
    return math.min(Const.TICK_LIVE_COLD_MS, 500)
end
