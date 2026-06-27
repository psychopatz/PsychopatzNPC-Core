PNC = PNC or {}
PNC.Scheduler = PNC.Scheduler or {}

local Scheduler = PNC.Scheduler
local Const = PNC.Const

function Scheduler.GetCadence(record)
    if record.presenceState == Const.PRESENCE_ABSTRACT then
        return Const.TICK_ABSTRACT_MS
    end
    if record.runtime and record.runtime.target then
        return Const.TICK_LIVE_HOT_MS
    end
    if tostring(record.activeJob or "") == "PatrolRoute" or tostring(record.activeJob or "") == "FollowOwner" then
        return Const.TICK_LIVE_WARM_MS
    end
    return Const.TICK_LIVE_COLD_MS
end
