--[[
    PNC Behavior Move Intent
    Owns behavior-authored movement intent so follow, combat, and hold logic
    can describe desired locomotion without directly resetting engine path
    state. The path service consumes this intent as the single live move lane.
]]

PNC = PNC or {}
PNC.BehaviorMoveIntent = PNC.BehaviorMoveIntent or {}

local MoveIntent = PNC.BehaviorMoveIntent
local Core = PNC.Core

local function ensureRuntime(record)
    record.runtime = record.runtime or {}
    return record.runtime
end

function MoveIntent.RequestMove(record, x, y, z, mode, stopDistance, reason)
    local runtime
    if not record then
        return false
    end
    runtime = ensureRuntime(record)
    runtime.moveIntent = {
        kind = "move",
        x = tonumber(x) or record.x,
        y = tonumber(y) or record.y,
        z = tonumber(z) or record.z or 0,
        mode = tostring(mode or "walk"),
        stopDistance = tonumber(stopDistance) or 0.7,
        reason = reason or "move_request",
        requestedByJob = tostring(record.activeJob or "none"),
        requestedByBehavior = tostring(record.activeBehavior or record.activeJob or "none"),
        requestedOrder = tostring(record.orderSpec and record.orderSpec.kind or "none"),
        combatReason = tostring(runtime.combatBlockReason or "none"),
        updatedAt = Core.Now(),
    }
    return true
end

function MoveIntent.Hold(record, reason)
    local runtime
    if not record then
        return false
    end
    runtime = ensureRuntime(record)
    runtime.moveIntent = {
        kind = "hold",
        reason = reason or "hold",
        requestedByJob = tostring(record.activeJob or "none"),
        requestedByBehavior = tostring(record.activeBehavior or record.activeJob or "none"),
        requestedOrder = tostring(record.orderSpec and record.orderSpec.kind or "none"),
        updatedAt = Core.Now(),
    }
    return true
end

function MoveIntent.Get(record)
    return record and record.runtime and record.runtime.moveIntent or nil
end
