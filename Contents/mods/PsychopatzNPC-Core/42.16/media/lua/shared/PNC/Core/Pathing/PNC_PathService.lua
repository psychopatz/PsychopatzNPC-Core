--[[
    PNC Path Service
    Owns live embodied path requests, repath recovery, door and window
    interaction, and abstract travel stepping for far-away NPC simulation.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
local Core = PNC.Core
local Const = PNC.Const
local Animation = PNC.Animation
local getActionStateName

local function roundHalf(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function getSquare(x, y, z)
    if not getCell then
        return nil
    end
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end

local function isSquareWalkable(x, y, z)
    local square = getSquare(x, y, z)
    if not square then
        return false
    end
    return square:isFree(false) and (not square:isSolid()) and (not square:isSolidTrans())
end

local function setWalkAnim(zombie, record, mode)
    local previousWalkType
    local walkType = "Walk"
    if mode == "run" then
        walkType = "Run"
    elseif mode == "sneak" then
        walkType = "SneakWalk"
    elseif mode == "crawl" then
        walkType = "Walk"
    end
    previousWalkType = zombie.getVariableString and zombie:getVariableString("PNCWalkType") or ""
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if previousWalkType == "" and zombie.setBumpType then
        zombie:setBumpType(mode == "run" and "PNC_IdleToRun" or "PNC_IdleToWalk")
    end
    if mode == "crawl" then
        Animation.Apply(zombie, record, "Crawl")
    else
        Animation.Apply(zombie, record, walkType)
    end
    if Animation and Animation.SyncLocomotion then
        Animation.SyncLocomotion(zombie)
    end
end

local function resetPathController(zombie)
    local behavior
    if not zombie then
        return
    end
    if getActionStateName and getActionStateName(zombie) == "walktoward" and zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
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

local function issuePathRequest(zombie, targetX, targetY, targetZ)
    local behavior
    if not zombie then
        return false
    end
    if getActionStateName(zombie) == "walktoward" and zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        zombie:changeState(ZombieIdleState.instance())
    end
    if zombie.getPathFindBehavior2 then
        behavior = zombie:getPathFindBehavior2()
        if behavior and behavior.pathToLocation and behavior.update then
            behavior:pathToLocation(targetX, targetY, targetZ)
            behavior:update()
            return true
        end
    end
    if zombie.pathToLocationF then
        zombie:pathToLocationF(targetX, targetY, targetZ)
        return true
    end
    if zombie.pathToLocation then
        zombie:pathToLocation(targetX, targetY, targetZ)
        return true
    end
    return false
end

getActionStateName = function(zombie)
    if not zombie or not zombie.getActionStateName then
        return ""
    end
    return string.lower(tostring(zombie:getActionStateName() or ""))
end

local function hasPath2(zombie)
    if not zombie or not zombie.getPath2 then
        return false
    end
    return zombie:getPath2() ~= nil
end

local function isRecoverableConflictState(actionState)
    if actionState == nil or actionState == "" or actionState == "walktoward" then
        return false
    end
    if actionState == "lunge" then
        return true
    end
    if string.find(actionState, "attack", 1, true) then
        return true
    end
    if string.find(actionState, "thump", 1, true) then
        return true
    end
    return false
end

local function recoverConflictingState(zombie, record, path)
    local actionState = getActionStateName(zombie)
    local goal = path and path.goal or nil
    if not zombie or not record or not path then
        return false
    end
    if not isRecoverableConflictState(actionState) then
        return false
    end
    Core.LogRecordDebug(
        record,
        "NPC "
            .. tostring(record.id)
            .. " recovering path state from "
            .. tostring(actionState)
            .. " goal="
            .. tostring(goal and goal.x or nil)
            .. ","
            .. tostring(goal and goal.y or nil)
            .. ","
            .. tostring(goal and goal.z or nil)
            .. " mode="
            .. tostring(path.mode or "walk")
    )
    resetPathController(zombie)
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        zombie:changeState(ZombieIdleState.instance())
    end
    path.phase = "requested"
    path.startedAt = 0
    setWalkAnim(zombie, record, path.mode or "walk")
    issuePathRequest(zombie, goal and goal.x or zombie:getX(), goal and goal.y or zombie:getY(), goal and goal.z or zombie:getZ())
    return true
end

local function openDoorForNPC(zombie, object)
    local square
    local properties
    local doorSound
    if not object or object:IsOpen() then
        return false
    end

    if IsoDoor and IsoDoor.getDoubleDoorIndex and IsoDoor.getDoubleDoorIndex(object) > -1 then
        if object.isLocked and (object:isLocked() or object:isLockedByKey() or object:isObstructed()) then
            return false
        end
        IsoDoor.toggleDoubleDoor(object, true)
    elseif IsoDoor and IsoDoor.getGarageDoorIndex and IsoDoor.getGarageDoorIndex(object) > -1 then
        if object.isLocked and (object:isLocked() or object:isLockedByKey() or object:isObstructed()) then
            return false
        end
        IsoDoor.toggleGarageDoor(object, true)
    else
        if ((object.isLocked and object:isLocked()) or (object.isLockedByKey and object:isLockedByKey()) or (object.isObstructed and object:isObstructed())) then
            return false
        end
        square = object:getSquare()
        if not square then
            return false
        end
        object:DirtySlice()
        square:InvalidateSpecialObjectPaths()
        object:ToggleDoorSilent()
        square:RecalcProperties()
        object:syncIsoObject(false, 1, nil, nil)
        LuaEventManager.triggerEvent("OnContainerUpdate")
        if FBORenderChunk and object.invalidateRenderChunkLevel then
            object:invalidateRenderChunkLevel(FBORenderChunk.DIRTY_OBJECT_MODIFY)
        end
    end

    properties = object:getProperties()
    doorSound = properties and properties:has("DoorSound") and properties:get("DoorSound") or "WoodDoor"
    if zombie.playSound then
        zombie:playSound(doorSound .. "Open")
    end
    return true
end

local function tryDoorOrWindowInteraction(zombie, record, goalX, goalY, goalZ)
    local cell
    local zx
    local zy
    local zz
    local fd
    local fdx
    local fdy
    local candidates
    local i
    local square
    local objects
    local j
    local object
    local facingSatisfied
    local targetDx
    local targetDy
    local candidatesByGoal

    if not zombie or not getCell then
        return false
    end

    cell = getCell()
    zx = math.floor(zombie:getX())
    zy = math.floor(zombie:getY())
    zz = zombie:getZ()
    fd = zombie:getForwardDirection()
    fdx = roundHalf(fd:getX())
    fdy = roundHalf(fd:getY())
    targetDx = roundHalf((goalX or zombie:getX()) - zombie:getX())
    targetDy = roundHalf((goalY or zombie:getY()) - zombie:getY())

    candidates = {
        { x = zx, y = zy, z = zz },
        { x = zx + fdx, y = zy + fdy, z = zz },
        { x = zx + targetDx, y = zy + targetDy, z = goalZ or zz },
        { x = zx + 1, y = zy, z = zz },
        { x = zx - 1, y = zy, z = zz },
        { x = zx, y = zy + 1, z = zz },
        { x = zx, y = zy - 1, z = zz },
    }

    candidatesByGoal = {}
    for i = 1, #candidates do
        if not candidatesByGoal[candidates[i].x .. ":" .. candidates[i].y .. ":" .. candidates[i].z] then
            candidatesByGoal[candidates[i].x .. ":" .. candidates[i].y .. ":" .. candidates[i].z] = true
        else
            candidates[i].skip = true
        end
    end

    for i = 1, #candidates do
        if not candidates[i].skip then
            square = cell:getGridSquare(candidates[i].x, candidates[i].y, candidates[i].z)
        else
            square = nil
        end
        if square then
            objects = square:getObjects()
            for j = 0, objects:size() - 1 do
                object = objects:get(j)
                if object then
                    facingSatisfied = zombie.isFacingObject and zombie:isFacingObject(object, 0.5)
                    if (instanceof(object, "IsoDoor") or (instanceof(object, "IsoThumpable") and object.isDoor and object:isDoor() == true)) then
                        if (not facingSatisfied) and zombie.faceThisObject then
                            zombie:faceThisObject(object)
                            facingSatisfied = true
                        end
                    end
                    if (instanceof(object, "IsoDoor") or (instanceof(object, "IsoThumpable") and object.isDoor and object:isDoor() == true)) and facingSatisfied then
                        if openDoorForNPC(zombie, object) then
                            return true
                        end
                    end
                    if instanceof(object, "IsoWindow") then
                        if (not facingSatisfied) and zombie.faceThisObject then
                            zombie:faceThisObject(object)
                            facingSatisfied = true
                        end
                    end
                    if instanceof(object, "IsoWindow") and facingSatisfied then
                        if (not object:IsOpen()) and (not object:isSmashed()) and (not object:isPermaLocked()) then
                            object:ToggleWindow(zombie)
                            return true
                        end
                        if object:canClimbThrough(zombie) then
                            ClimbThroughWindowState.instance():setParams(zombie, object)
                            zombie:changeState(ClimbThroughWindowState.instance())
                            zombie:setBumpType("ClimbWindow")
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

local function ensureMoveLane(record)
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
    return lane
end

local function buildGoal(x, y, z, mode, stopDistance)
    return {
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
        mode = tostring(mode or "walk"),
        stopDistance = tonumber(stopDistance) or 0.7,
    }
end

local function getGoalTolerance(mode)
    return tostring(mode or "walk") == "run" and 2.0 or 1.25
end

local function goalsDiffer(currentGoal, nextGoal, currentMode)
    local tolerance
    if not currentGoal or not nextGoal then
        return true
    end
    tolerance = getGoalTolerance(currentMode or nextGoal.mode)
    return math.abs((currentGoal.x or 0) - (nextGoal.x or 0)) > tolerance
        or math.abs((currentGoal.y or 0) - (nextGoal.y or 0)) > tolerance
        or (currentGoal.z or 0) ~= (nextGoal.z or 0)
        or tostring(currentMode or "") ~= tostring(nextGoal.mode or "")
end

local function isMovePhaseActive(phase)
    return phase == "requested" or phase == "active"
end

local function logMoveTransition(record, lane, verb, reason)
    local goal = lane and lane.goal or nil
    Core.LogRecordDebug(
        record,
        "NPC "
            .. tostring(record.id)
            .. " move "
            .. tostring(verb)
            .. " phase="
            .. tostring(lane and lane.phase or "nil")
            .. " mode="
            .. tostring(lane and lane.mode or "nil")
            .. " goal="
            .. tostring(goal and goal.x or nil)
            .. ","
            .. tostring(goal and goal.y or nil)
            .. ","
            .. tostring(goal and goal.z or nil)
            .. " reason="
            .. tostring(reason or "none")
    )
end

local function setLanePhase(record, lane, phase, reason)
    if not lane or lane.phase == phase then
        return
    end
    lane.phase = phase
    logMoveTransition(record, lane, phase, reason)
end

local function setLaneGoal(record, lane, goal)
    lane.id = (tonumber(lane.id) or 0) + 1
    lane.goal = {
        x = goal.x,
        y = goal.y,
        z = goal.z,
    }
    lane.mode = goal.mode
    lane.stopDistance = goal.stopDistance
    lane.blockReason = nil
    lane.cancelReason = nil
end

local function applyHoldAnimation(zombie, record, lane)
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
    Animation.Apply(zombie, record, "Idle")
end

local function isAtGoal(zombie, goal, stopDistance)
    local dist
    if not zombie or not goal then
        return false
    end
    dist = Core.Distance(zombie:getX(), zombie:getY(), goal.x, goal.y)
    return dist <= (tonumber(stopDistance) or 0.7) and zombie:getZ() == goal.z
end

local function consumeMoveIntent(record, lane, zombie)
    local runtime = record and record.runtime or nil
    local intent = runtime and runtime.moveIntent or nil
    local goal
    if not runtime then
        return "hold"
    end
    if not intent or intent.kind == "hold" then
        lane.pendingGoal = nil
        if lane.phase == "active" or lane.phase == "requested" then
            lane.cancelReason = intent and intent.reason or "hold"
            setLanePhase(record, lane, "cancel_pending", lane.cancelReason)
        elseif lane.phase ~= "idle" then
            setLanePhase(record, lane, "idle", intent and intent.reason or "hold")
        end
        return "hold"
    end

    goal = buildGoal(intent.x, intent.y, intent.z, intent.mode, intent.stopDistance)
    if zombie and isAtGoal(zombie, goal, goal.stopDistance) then
        lane.pendingGoal = nil
        lane.goal = goal
        lane.mode = goal.mode
        lane.stopDistance = goal.stopDistance
        if lane.phase == "active" or lane.phase == "requested" then
            lane.cancelReason = "arrived"
            setLanePhase(record, lane, "cancel_pending", "arrived")
        else
            setLanePhase(record, lane, "arrived", "intent_arrived")
        end
        return "arrived"
    end

    if lane.goal == nil or lane.phase == "idle" or lane.phase == "arrived" or lane.phase == "blocked" then
        setLaneGoal(record, lane, goal)
        lane.pendingGoal = nil
        setLanePhase(record, lane, "requested", "new_goal")
        return "requested"
    end

    if goalsDiffer(lane.goal, goal, lane.mode) then
        lane.pendingGoal = goal
        if lane.phase == "requested" then
            setLaneGoal(record, lane, goal)
            lane.pendingGoal = nil
            setLanePhase(record, lane, "requested", "goal_refresh")
            return "requested"
        end
        return "refresh_pending"
    end

    return "unchanged"
end

local function finalizeCancel(zombie, record, lane)
    if zombie then
        resetPathController(zombie)
    end
    lane.pendingGoal = nil
    lane.lastIssueAt = 0
    lane.lastProgressAt = 0
    lane.startedAt = 0
    setLanePhase(record, lane, "idle", lane.cancelReason or "cancelled")
    applyHoldAnimation(zombie, record, lane)
    return true, "cancelled"
end

local function startRequestedMove(zombie, record, lane)
    local now
    local goal = lane and lane.goal or nil
    if not zombie or not lane or not goal then
        return false, "no_goal"
    end
    now = Core.Now()
    resetPathController(zombie)
    setWalkAnim(zombie, record, lane.mode or goal.mode)
    if not issuePathRequest(zombie, goal.x, goal.y, goal.z) then
        lane.blockReason = "path_request_failed"
        setLanePhase(record, lane, "blocked", lane.blockReason)
        applyHoldAnimation(zombie, record, lane)
        return false, "path_request_failed"
    end
    lane.startedAt = now
    lane.lastIssueAt = now
    lane.lastProgressAt = now
    lane.lastX = zombie:getX()
    lane.lastY = zombie:getY()
    setLanePhase(record, lane, "active", "started")
    return true, "started"
end

local function completeMove(zombie, record, lane, phase, reason)
    if zombie then
        resetPathController(zombie)
    end
    lane.pendingGoal = nil
    lane.startedAt = 0
    lane.lastIssueAt = 0
    lane.lastProgressAt = 0
    lane.cancelReason = phase == "arrived" and reason or lane.cancelReason
    lane.blockReason = phase == "blocked" and reason or nil
    setLanePhase(record, lane, phase, reason)
    applyHoldAnimation(zombie, record, lane)
    return true, reason
end

local function refreshPendingGoal(zombie, record, lane, reason)
    if not lane or not lane.pendingGoal then
        return false
    end
    setLaneGoal(record, lane, lane.pendingGoal)
    lane.pendingGoal = nil
    setLanePhase(record, lane, "requested", reason or "refresh")
    return startRequestedMove(zombie, record, lane)
end

local function restartCurrentGoal(zombie, record, lane, reason)
    if not lane or not lane.goal then
        return false, "no_goal"
    end
    setLanePhase(record, lane, "requested", reason or "restart")
    return startRequestedMove(zombie, record, lane)
end

local function updateActiveMove(zombie, record, lane)
    local behavior
    local behaviorResult
    local goal = lane and lane.goal or nil
    local now
    local zx
    local zy
    local moved

    if not zombie or not lane or not goal then
        return false, "no_goal"
    end

    now = Core.Now()
    if recoverConflictingState(zombie, record, lane) then
        lane.lastIssueAt = now
        lane.lastProgressAt = now
        lane.lastX = zombie:getX()
        lane.lastY = zombie:getY()
        return true, "state_recovered"
    end

    if zombie.getPathFindBehavior2 then
        behavior = zombie:getPathFindBehavior2()
        if behavior and behavior.update then
            behaviorResult = behavior:update()
        end
    end

    if lane.pendingGoal and (now - (tonumber(lane.lastIssueAt) or 0)) >= 120 then
        return refreshPendingGoal(zombie, record, lane, "goal_refresh")
    end

    if isAtGoal(zombie, goal, lane.stopDistance) then
        return completeMove(zombie, record, lane, "arrived", "arrived")
    end

    if BehaviorResult and behaviorResult == BehaviorResult.Succeeded then
        return completeMove(zombie, record, lane, "arrived", "behavior_succeeded")
    end

    zx = zombie:getX()
    zy = zombie:getY()
    if lane.lastX ~= nil and lane.lastY ~= nil then
        moved = Core.Distance(lane.lastX, lane.lastY, zx, zy)
        if moved > 0.05 then
            lane.lastX = zx
            lane.lastY = zy
            lane.lastProgressAt = now
            return true, "moving"
        end
    end

    if tryDoorOrWindowInteraction(zombie, record, goal.x, goal.y, goal.z) then
        lane.lastIssueAt = now
        lane.lastProgressAt = now
        issuePathRequest(zombie, goal.x, goal.y, goal.z)
        return true, "interact"
    end

    if BehaviorResult and behaviorResult == BehaviorResult.Failed then
        if lane.pendingGoal then
            return refreshPendingGoal(zombie, record, lane, "behavior_failed")
        end
        return restartCurrentGoal(zombie, record, lane, "behavior_failed")
    end

    if (now - (tonumber(lane.lastProgressAt) or 0)) >= 1200 then
        if issuePathRequest(zombie, goal.x, goal.y, goal.z) then
            lane.lastIssueAt = now
            lane.lastProgressAt = now
            lane.lastX = zombie:getX()
            lane.lastY = zombie:getY()
            logMoveTransition(record, lane, "refreshed", "progress_timeout")
            return true, "repath"
        end
        if (not isServer or not isServer()) and isSquareWalkable(goal.x, goal.y, goal.z) then
            zombie:setX(goal.x)
            zombie:setY(goal.y)
            zombie:setZ(goal.z)
            return completeMove(zombie, record, lane, "arrived", "fallback_snap")
        end
        return completeMove(zombie, record, lane, "blocked", "progress_timeout")
    end

    return true, "waiting"
end

function PathService.Reset(zombie, record)
    if record and record.runtime then
        record.runtime.pathing = nil
        record.runtime.moveIntent = nil
    end
    resetPathController(zombie)
end

function PathService.MoveToward(record, zombie, targetX, targetY, targetZ, mode, stopDistance)
    record.runtime = record.runtime or {}
    record.runtime.moveIntent = {
        kind = "move",
        x = tonumber(targetX) or record.x,
        y = tonumber(targetY) or record.y,
        z = tonumber(targetZ) or record.z or 0,
        mode = tostring(mode or "walk"),
        stopDistance = tonumber(stopDistance) or 0.7,
        reason = "path_service_move",
        updatedAt = Core.Now(),
    }
    if zombie and isAtGoal(zombie, buildGoal(targetX, targetY, targetZ, mode, stopDistance), stopDistance) then
        return true, "arrived"
    end
    return true, "move_intent"
end

function PathService.Pump(record, zombie)
    local runtime = record and record.runtime or nil
    local lane
    local intentState
    if not zombie or not runtime then
        return false, "no_live_body"
    end

    lane = ensureMoveLane(record)
    intentState = consumeMoveIntent(record, lane, zombie)

    if lane.phase == "cancel_pending" then
        finalizeCancel(zombie, record, lane)
        intentState = consumeMoveIntent(record, lane, zombie)
    end

    if lane.phase == "requested" then
        return startRequestedMove(zombie, record, lane)
    end

    if lane.phase == "active" then
        return updateActiveMove(zombie, record, lane)
    end

    if intentState == "arrived" then
        applyHoldAnimation(zombie, record, lane)
        return true, "arrived"
    end

    applyHoldAnimation(zombie, record, lane)
    return false, "idle"
end

function PathService.AdvanceAbstract(record, targetX, targetY, targetZ, stopDistance)
    local dist
    local dx
    local dy
    local len
    local step = Const.ABSTRACT_TRAVEL_STEP
    stopDistance = tonumber(stopDistance) or 1.0
    dist = Core.Distance(record.x, record.y, targetX, targetY)
    if dist <= stopDistance and record.z == targetZ then
        return true
    end
    dx = targetX - record.x
    dy = targetY - record.y
    len = math.sqrt((dx * dx) + (dy * dy))
    if len <= 0 then
        return true
    end
    record.x = record.x + (dx / len) * math.min(step, len)
    record.y = record.y + (dy / len) * math.min(step, len)
    record.z = targetZ
    return false
end
