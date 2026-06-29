--[[
    PNC Path Service Lane
    Shared movement-lane state and intent consumption helpers.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

local Internal = PathService.Internal

function Internal.ensureMoveLane(record)
    local runtime
    local lane
    if not record then
        return nil
    end
    record.runtime = record.runtime or {}
    runtime = record.runtime
    lane = runtime.pathing or {}
    runtime.pathing = lane
    lane.id = lane.id or 0
    lane.phase = lane.phase or "idle"
    lane.mode = lane.mode or "walk"
    lane.stopDistance = tonumber(lane.stopDistance) or 0.7
    lane.goal = lane.goal or nil
    lane.pendingGoal = lane.pendingGoal or nil
    lane.startedAt = tonumber(lane.startedAt) or 0
    lane.lastIssueAt = tonumber(lane.lastIssueAt) or 0
    lane.lastProgressAt = tonumber(lane.lastProgressAt) or 0
    lane.cancelReason = lane.cancelReason or nil
    lane.blockReason = lane.blockReason or nil
    lane.intentReason = lane.intentReason or nil
    lane.requestedByJob = lane.requestedByJob or nil
    lane.requestedByBehavior = lane.requestedByBehavior or nil
    lane.requestedOrder = lane.requestedOrder or nil
    lane.lastWarnKey = lane.lastWarnKey or nil
    lane.lastWarnAt = tonumber(lane.lastWarnAt) or 0
    lane.goalRevision = tonumber(lane.goalRevision) or 0
    lane.recoveryCount = tonumber(lane.recoveryCount) or 0
    lane.fallbackCount = tonumber(lane.fallbackCount) or 0
    lane.lastRecoveryReason = lane.lastRecoveryReason or nil
    lane.lastActionState = lane.lastActionState or nil
    lane.lastDirectStepAt = tonumber(lane.lastDirectStepAt) or 0
    lane.lastStepAt = tonumber(lane.lastStepAt) or 0
    lane.lastStepDistance = tonumber(lane.lastStepDistance) or 0
    lane.lastStepLabel = lane.lastStepLabel or nil
    lane.lastRecoverAt = tonumber(lane.lastRecoverAt) or 0
    lane.noProgressCount = tonumber(lane.noProgressCount) or 0
    lane.lastSpecialActionKey = lane.lastSpecialActionKey or nil
    lane.lastSpecialActionAt = tonumber(lane.lastSpecialActionAt) or 0
    lane.specialMoveUntil = tonumber(lane.specialMoveUntil) or 0
    lane.specialAnim = lane.specialAnim or nil
    lane.resolvedMode = lane.resolvedMode or nil
    lane.animSpeed = tonumber(lane.animSpeed) or 1.0
    lane.lastSuppressAudioAt = tonumber(lane.lastSuppressAudioAt) or 0
    lane.ownerMode = lane.ownerMode or "idle"
    lane.facingOwner = lane.facingOwner or "idle"
    lane.combatFacingUntil = tonumber(lane.combatFacingUntil) or 0
    lane.combatFacingX = lane.combatFacingX ~= nil and tonumber(lane.combatFacingX) or nil
    lane.combatFacingY = lane.combatFacingY ~= nil and tonumber(lane.combatFacingY) or nil
    lane.combatFacingZ = lane.combatFacingZ ~= nil and tonumber(lane.combatFacingZ) or nil
    lane.combatFacingReason = lane.combatFacingReason or nil
    lane.lastFacingAt = tonumber(lane.lastFacingAt) or 0
    lane.lastFacingDirX = lane.lastFacingDirX ~= nil and tonumber(lane.lastFacingDirX) or nil
    lane.lastFacingDirY = lane.lastFacingDirY ~= nil and tonumber(lane.lastFacingDirY) or nil
    lane.lastFacingX = lane.lastFacingX ~= nil and tonumber(lane.lastFacingX) or nil
    lane.lastFacingY = lane.lastFacingY ~= nil and tonumber(lane.lastFacingY) or nil
    return lane
end

function Internal.setLanePhase(record, lane, phase, reason)
    if not lane or lane.phase == phase then
        return
    end
    lane.phase = phase
    Internal.logMoveTransition(record, nil, lane, phase, reason)
end

function Internal.setLaneGoal(record, lane, goal)
    lane.id = (tonumber(lane.id) or 0) + 1
    lane.goalRevision = (tonumber(lane.goalRevision) or 0) + 1
    lane.goal = {
        x = goal.x,
        y = goal.y,
        z = goal.z,
        mode = goal.mode,
        stopDistance = goal.stopDistance,
    }
    lane.mode = goal.mode
    lane.stopDistance = goal.stopDistance
    lane.blockReason = nil
    lane.cancelReason = nil
    lane.recoveryCount = 0
    lane.fallbackCount = 0
    lane.lastRecoveryReason = nil
    lane.lastRecoverAt = 0
    lane.noProgressCount = 0
    lane.lastStepAt = 0
    lane.lastStepDistance = 0
    lane.lastStepLabel = nil
    lane.lastSuppressAudioAt = 0
    lane.specialMoveUntil = 0
    lane.specialAnim = nil
    lane.resolvedMode = nil
    lane.animSpeed = 1.0
    lane.ownerMode = "requested"
end

function Internal.captureIntentContext(record, lane, intent)
    if not lane then
        return
    end
    lane.intentReason = intent and intent.reason or nil
    lane.requestedByJob = intent and intent.requestedByJob or tostring(record and record.activeJob or "none")
    lane.requestedByBehavior = intent and intent.requestedByBehavior or tostring(record and record.activeBehavior or record and record.activeJob or "none")
    lane.requestedOrder = intent and intent.requestedOrder or tostring(record and record.orderSpec and record.orderSpec.kind or "none")
end

function Internal.consumeMoveIntent(record, lane, zombie)
    local runtime = record and record.runtime or nil
    local intent = runtime and runtime.moveIntent or nil
    local goal
    if not runtime then
        return "hold"
    end
    if not intent or intent.kind == "hold" then
        Internal.captureIntentContext(record, lane, intent)
        lane.pendingGoal = nil
        if lane.phase == "active" or lane.phase == "requested" then
            lane.cancelReason = intent and intent.reason or "hold"
            Internal.setLanePhase(record, lane, "cancel_pending", lane.cancelReason)
        elseif lane.phase ~= "idle" then
            Internal.setLanePhase(record, lane, "idle", intent and intent.reason or "hold")
        end
        return "hold"
    end

    goal = Internal.buildGoal(intent.x, intent.y, intent.z, intent.mode, intent.stopDistance)
    Internal.captureIntentContext(record, lane, intent)
    if zombie and Internal.isAtGoal(zombie, goal, goal.stopDistance) then
        lane.pendingGoal = nil
        lane.goal = goal
        lane.mode = goal.mode
        lane.stopDistance = goal.stopDistance
        if lane.phase == "active" or lane.phase == "requested" then
            lane.cancelReason = "arrived"
            Internal.setLanePhase(record, lane, "cancel_pending", "arrived")
        else
            Internal.setLanePhase(record, lane, "arrived", "intent_arrived")
        end
        return "arrived"
    end

    if lane.goal == nil or lane.phase == "idle" or lane.phase == "arrived" or lane.phase == "blocked" then
        Internal.setLaneGoal(record, lane, goal)
        lane.pendingGoal = nil
        Internal.setLanePhase(record, lane, "requested", "new_goal")
        return "requested"
    end

    if Internal.goalsDiffer(lane.goal, goal, lane.mode) then
        lane.pendingGoal = goal
        if lane.phase == "requested" then
            Internal.setLaneGoal(record, lane, goal)
            lane.pendingGoal = nil
            Internal.setLanePhase(record, lane, "requested", "goal_refresh")
            return "requested"
        end
        return "refresh_pending"
    end

    return "unchanged"
end
