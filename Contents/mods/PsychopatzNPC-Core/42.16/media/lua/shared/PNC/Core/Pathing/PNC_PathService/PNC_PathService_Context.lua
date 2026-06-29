--[[
    PNC Path Service Context
    Shared constants and core helpers for the split pathing subsystem.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

local Internal = PathService.Internal
local Core = PNC.Core
local Animation = PNC.Animation
local LiveBodyControl = PNC.LiveBodyControl
local FakeLocomotion = PNC.FakeLocomotion

Internal.Core = Core
Internal.Animation = Animation
Internal.LiveBodyControl = LiveBodyControl
Internal.FakeLocomotion = FakeLocomotion

Internal.GOAL_REFRESH_DELAY_MS = 120
Internal.PROGRESS_TIMEOUT_MS = 2200
Internal.SPECIAL_ACTION_COOLDOWN_MS = 1500
Internal.RUN_START_DISTANCE = 4.50
Internal.RUN_STOP_DISTANCE = 2.90
Internal.FACE_REAPPLY_INTERVAL_MS = 90
Internal.FACE_SIMILAR_DOT = 0.985
Internal.FACE_MIN_DISTANCE_SQ = 0.0036
Internal.COMBAT_FACING_DEFAULT_MS = 180

function Internal.roundHalf(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function Internal.getSquare(x, y, z)
    if not getCell then
        return nil
    end
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end

function Internal.isSquareWalkable(x, y, z)
    local square = Internal.getSquare(x, y, z)
    if not square then
        return false
    end
    return square:isFree(false) and (not square:isSolid()) and (not square:isSolidTrans())
end

function Internal.syncRecordPosition(record, zombie)
    if not record or not zombie then
        return
    end
    record.x = zombie:getX()
    record.y = zombie:getY()
    record.z = zombie:getZ()
end

function Internal.isMovementDebugEnabled(record)
    if record and record.runtime and record.runtime.debugMovement == true then
        return true
    end
    if PNC.Runtime and PNC.Runtime.debugMovement == true then
        return true
    end
    if Core and Core.IsRecordDebugEnabled then
        return Core.IsRecordDebugEnabled(record)
    end
    return PNC.Runtime and PNC.Runtime.debugEnabled == true
end

function Internal.hasActiveAttack(record, now)
    local runtime = record and record.runtime or nil
    local attackAction = runtime and runtime.attackAction or nil
    now = tonumber(now) or Core.Now()
    return attackAction ~= nil and now < (tonumber(attackAction.finishAt) or 0)
end

function Internal.setWalkAnim(zombie, record, mode, force)
    local previousWalkType
    local walkTypeChanged
    local walkType = "Walk"
    if mode == "run" then
        walkType = "Run"
    elseif mode == "sneak" then
        walkType = "SneakWalk"
    elseif mode == "crawl" then
        walkType = "Walk"
    end
    previousWalkType = zombie.getVariableString and zombie:getVariableString("PNCWalkType") or ""
    walkTypeChanged = previousWalkType ~= walkType
    if (force == true or walkTypeChanged) and previousWalkType == "" and zombie.setBumpType then
        zombie:setBumpType(mode == "run" and "PNC_IdleToRun" or "PNC_IdleToWalk")
    end
    if mode == "crawl" then
        Animation.Apply(zombie, record, "Crawl")
    else
        Animation.Apply(zombie, record, walkType)
    end
    if Animation and Animation.SyncLocomotion then
        Animation.SyncLocomotion(zombie, record)
    end
end

function Internal.resetPathController(zombie)
    local behavior
    if not zombie then
        return
    end
    if Internal.getActionStateName and Internal.getActionStateName(zombie) == "walktoward"
        and zombie.changeState and ZombieIdleState and ZombieIdleState.instance
    then
        zombie:changeState(ZombieIdleState.instance())
    end
    if zombie.getPathFindBehavior2 then
        behavior = zombie:getPathFindBehavior2()
        if behavior then
            behavior:update()
            behavior:cancel()
            behavior:reset()
        end
    end
    if zombie.setPath2 then
        zombie:setPath2(nil)
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
end

function Internal.hardResetMoveOwner(zombie)
    if not zombie then
        return
    end
    Internal.resetPathController(zombie)
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
    if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        zombie:changeState(ZombieIdleState.instance())
    end
    if zombie.setRunning then
        zombie:setRunning(false)
    end
end

function Internal.getActionStateName(zombie)
    if LiveBodyControl and LiveBodyControl.GetActionStateName then
        return LiveBodyControl.GetActionStateName(zombie)
    end
    if not zombie or not zombie.getActionStateName then
        return ""
    end
    return string.lower(tostring(zombie:getActionStateName() or ""))
end

function Internal.hasPath2(zombie)
    if not zombie or not zombie.getPath2 then
        return false
    end
    return zombie:getPath2() ~= nil
end

function Internal.buildGoal(x, y, z, mode, stopDistance)
    return {
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
        mode = tostring(mode or "walk"),
        stopDistance = tonumber(stopDistance) or 0.7,
    }
end

function Internal.getGoalTolerance(mode, stopDistance)
    local tolerance = tostring(mode or "walk") == "run" and 1.75 or 1.0
    if mode == "sneak" or mode == "crawl" then
        tolerance = 0.6
    end
    if tonumber(stopDistance) and tonumber(stopDistance) > tolerance then
        tolerance = math.min(tonumber(stopDistance) * 1.25, tolerance + 0.75)
    end
    return tolerance
end

function Internal.computeResolvedMode(record, lane, zombie, goal)
    local dist
    local previousMode
    if not lane or not goal then
        return "walk"
    end
    if lane.mode == "crawl" then
        return "crawl"
    end
    if lane.mode == "sneak" or (record and record.runtime and record.runtime.stealthActive == true) then
        return "sneak"
    end
    if lane.mode ~= "walk" and lane.mode ~= "run" then
        return tostring(lane.mode or "walk")
    end
    if not zombie then
        return tostring(lane.mode or "walk")
    end
    dist = Core.Distance(zombie:getX(), zombie:getY(), goal.x, goal.y)
    previousMode = tostring(lane.resolvedMode or lane.mode or "walk")
    if previousMode == "run" then
        if dist <= math.max(tonumber(lane.stopDistance) or 0.7, Internal.RUN_STOP_DISTANCE) then
            return "walk"
        end
        return "run"
    end
    if dist >= math.max((tonumber(lane.stopDistance) or 0.7) + 2.75, Internal.RUN_START_DISTANCE) then
        return "run"
    end
    return "walk"
end

function Internal.computeAnimSpeedForMode(mode)
    if FakeLocomotion and FakeLocomotion.ComputeAnimSpeed then
        return FakeLocomotion.ComputeAnimSpeed(mode)
    end
    return 1.0
end

function Internal.refreshResolvedLocomotion(record, lane, zombie, goal)
    local resolvedMode = Internal.computeResolvedMode(record, lane, zombie, goal)
    if lane then
        lane.resolvedMode = resolvedMode
        lane.animSpeed = Internal.computeAnimSpeedForMode(resolvedMode)
    end
    return resolvedMode
end

function Internal.getStopDistanceClass(stopDistance)
    local value = tonumber(stopDistance) or 0.7
    if value <= 0.35 then
        return "tight"
    end
    if value <= 0.9 then
        return "near"
    end
    return "wide"
end

function Internal.goalsDiffer(currentGoal, nextGoal, currentMode)
    local tolerance
    if not currentGoal or not nextGoal then
        return true
    end
    tolerance = Internal.getGoalTolerance(currentMode or nextGoal.mode, nextGoal.stopDistance)
    return math.abs((currentGoal.x or 0) - (nextGoal.x or 0)) > tolerance
        or math.abs((currentGoal.y or 0) - (nextGoal.y or 0)) > tolerance
        or (currentGoal.z or 0) ~= (nextGoal.z or 0)
        or tostring(currentMode or "") ~= tostring(nextGoal.mode or "")
        or Internal.getStopDistanceClass(currentGoal.stopDistance) ~= Internal.getStopDistanceClass(nextGoal.stopDistance)
end

function Internal.applyHoldAnimation(zombie, record, lane)
    local healthState = record and record.health and tostring(record.health.state or "normal") or "normal"
    local attackAction = record and record.runtime and record.runtime.attackAction or nil
    if not zombie or not record then
        return
    end
    if attackAction and Core.Now() < (tonumber(attackAction.finishAt) or 0) then
        return
    end
    if healthState == "incapacitated" and Animation and Animation.ApplyDowned then
        Animation.ApplyDowned(zombie, record, false)
        return
    end
    if lane and lane.mode == "crawl" then
        Animation.Apply(zombie, record, "Crawl")
        return
    end
    if lane and (lane.mode == "sneak" or (record and record.runtime and record.runtime.stealthActive == true)) then
        Animation.Apply(zombie, record, "SneakWalk")
        return
    end
    Animation.Apply(zombie, record, "Idle")
end

function Internal.isAtGoal(zombie, goal, stopDistance)
    local dist
    if not zombie or not goal then
        return false
    end
    dist = Core.Distance(zombie:getX(), zombie:getY(), goal.x, goal.y)
    return dist <= (tonumber(stopDistance) or 0.7) and zombie:getZ() == goal.z
end
