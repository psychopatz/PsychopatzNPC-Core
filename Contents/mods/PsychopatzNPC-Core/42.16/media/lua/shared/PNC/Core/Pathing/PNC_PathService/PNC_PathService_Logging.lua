--[[
    PNC Path Service Logging
    Focused move diagnostics and log formatting helpers.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

local Internal = PathService.Internal
local Core = PNC.Core

function Internal.describeGoal(goal)
    if not goal then
        return "nil"
    end
    return tostring(goal.x) .. "," .. tostring(goal.y) .. "," .. tostring(goal.z)
end

function Internal.describePoint(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

function Internal.describeSquare(square)
    if not square then
        return "nil"
    end
    return Internal.describePoint(square:getX(), square:getY(), square:getZ())
end

function Internal.describeRecord(record)
    if not record then
        return "npc[nil]"
    end
    return tostring(record.name or "Unknown NPC")
        .. "["
        .. tostring(record.id or "nil")
        .. "]"
        .. " faction="
        .. tostring(record.faction or "unknown")
        .. " job="
        .. tostring(record.activeJob or "nil")
        .. " behavior="
        .. tostring(record.activeBehavior or "nil")
        .. " order="
        .. tostring(record.orderSpec and record.orderSpec.kind or "none")
end

function Internal.describeZombieTarget(zombie)
    local target
    local name
    if not zombie or not zombie.getTarget then
        return "nil"
    end
    target = zombie:getTarget()
    if not target then
        return "nil"
    end
    if target.getUsername then
        name = target:getUsername()
    elseif target.getDescriptor and target:getDescriptor() and target:getDescriptor().getForename then
        name = target:getDescriptor():getForename()
    end
    return tostring(name or tostring(target))
end

function Internal.buildMoveLogMessage(record, zombie, lane, event, reason, extra)
    local goal = lane and lane.goal or nil
    local intentReason = lane and lane.intentReason or record and record.runtime and record.runtime.moveIntent and record.runtime.moveIntent.reason or nil
    local requestedBy = lane and lane.requestedByBehavior or record and record.activeBehavior or record and record.activeJob or "nil"
    local actionState = Internal.getActionStateName(zombie)
    return Internal.describeRecord(record)
        .. " move="
        .. tostring(event or "unknown")
        .. " phase="
        .. tostring(lane and lane.phase or "nil")
        .. " mode="
        .. tostring(lane and lane.mode or "nil")
        .. " reason="
        .. tostring(reason or "none")
        .. " intentReason="
        .. tostring(intentReason or "none")
        .. " requestedBy="
        .. tostring(requestedBy)
        .. " goal="
        .. Internal.describeGoal(goal)
        .. " revision="
        .. tostring(lane and lane.goalRevision or 0)
        .. " action="
        .. tostring(actionState ~= "" and actionState or "idle")
        .. " lastAction="
        .. tostring(lane and lane.lastActionState or (actionState ~= "" and actionState or "idle"))
        .. " path2="
        .. tostring(Internal.hasPath2(zombie))
        .. " owner="
        .. tostring(lane and lane.ownerMode or "none")
        .. " recoveries="
        .. tostring(lane and lane.recoveryCount or 0)
        .. " fallbacks="
        .. tostring(lane and lane.fallbackCount or 0)
        .. " target="
        .. Internal.describeZombieTarget(zombie)
        .. " pos="
        .. tostring(zombie and zombie.getX and string.format("%.2f", zombie:getX()) or "nil")
        .. ","
        .. tostring(zombie and zombie.getY and string.format("%.2f", zombie:getY()) or "nil")
        .. ","
        .. tostring(zombie and zombie.getZ and zombie:getZ() or "nil")
        .. (extra and extra ~= "" and (" " .. tostring(extra)) or "")
end

function Internal.logMoveWarning(record, zombie, lane, event, reason, extra)
    local now = Core.Now()
    local key = tostring(event or "unknown")
        .. "|"
        .. tostring(reason or "none")
        .. "|"
        .. tostring(lane and lane.phase or "nil")
        .. "|"
        .. tostring(Internal.getActionStateName(zombie))
        .. "|"
        .. tostring(Internal.hasPath2(zombie))
    if lane and lane.lastWarnKey == key and (now - (tonumber(lane.lastWarnAt) or 0)) < 1500 then
        return
    end
    if lane then
        lane.lastWarnKey = key
        lane.lastWarnAt = now
    end
    Core.LogWarn(Internal.buildMoveLogMessage(record, zombie, lane, event, reason, extra))
end

function Internal.logMoveDebug(record, zombie, lane, event, reason, extra)
    if not Internal.isMovementDebugEnabled(record) then
        return
    end
    Core.Log("DEBUG", Internal.buildMoveLogMessage(record, zombie, lane, event, reason, extra))
end

function Internal.logMoveTransition(record, zombie, lane, verb, reason, extra)
    Internal.logMoveDebug(record, zombie, lane, verb, reason, extra)
end
