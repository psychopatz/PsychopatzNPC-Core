PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
local Core = PNC.Core
local Const = PNC.Const
local Animation = PNC.Animation

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
    local walkType = "Walk"
    if mode == "run" then
        walkType = "Run"
    elseif mode == "sneak" then
        walkType = "SneakWalk"
    elseif mode == "crawl" then
        walkType = "Walk"
    end
    if zombie.setVariable then
        zombie:setVariable("PNCWalkType", walkType)
    end
    if zombie.setWalkType then
        zombie:setWalkType(walkType)
    end
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if zombie.setBumpType then
        if mode == "run" then
            zombie:setBumpType("IdleToRun")
        else
            zombie:setBumpType("IdleToWalk")
        end
    end
    if mode == "crawl" then
        Animation.Apply(zombie, record, "Crawl")
    else
        Animation.Apply(zombie, record, walkType)
    end
end

local function resetPathController(zombie)
    local behavior
    if not zombie then
        return
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

local function ensurePathRequest(zombie, record, targetX, targetY, targetZ, mode, stopDistance)
    local runtime = record.runtime
    local path = runtime.pathing or {}
    local changed
    local goalTolerance

    runtime.pathing = path
    goalTolerance = mode == "run" and 2.0 or 1.25
    changed = path.goalX == nil
        or math.abs((path.goalX or 0) - targetX) > goalTolerance
        or math.abs((path.goalY or 0) - targetY) > goalTolerance
        or (path.goalZ or 0) ~= targetZ
        or path.mode ~= mode
        or path.finished == true

    if not changed then
        return
    end

    path.goalX = targetX
    path.goalY = targetY
    path.goalZ = targetZ
    path.mode = mode
    path.stopDistance = tonumber(stopDistance) or 0.7
    path.finished = false
    path.lastIssueAt = Core.Now()
    path.lastX = zombie:getX()
    path.lastY = zombie:getY()
    path.lastProgressAt = path.lastIssueAt

    setWalkAnim(zombie, record, mode)
    if path.wasActive ~= true then
        resetPathController(zombie)
    end
    path.wasActive = true

    if zombie.pathToLocationF then
        zombie:pathToLocationF(targetX, targetY, targetZ)
    elseif zombie.pathToLocation then
        zombie:pathToLocation(targetX, targetY, targetZ)
    end
end

local function updatePathRequest(zombie, record)
    local runtime = record.runtime
    local path = runtime and runtime.pathing or nil
    local now
    local zx
    local zy
    local zz
    local dist
    if not path or path.goalX == nil then
        return false, "no_path"
    end

    now = Core.Now()
    zx = zombie:getX()
    zy = zombie:getY()
    zz = zombie:getZ()
    dist = Core.Distance(zx, zy, path.goalX, path.goalY)

    if dist <= (tonumber(path.stopDistance) or 0.7) and zz == path.goalZ then
        path.finished = true
        path.wasActive = false
        resetPathController(zombie)
        return true, "arrived"
    end

    if path.lastX and Core.Distance(path.lastX, path.lastY, zx, zy) > 0.05 then
        path.lastX = zx
        path.lastY = zy
        path.lastProgressAt = now
        return true, "moving"
    end

    if tryDoorOrWindowInteraction(zombie, record, path.goalX, path.goalY, path.goalZ) then
        path.lastIssueAt = now
        if zombie.pathToLocationF then
            zombie:pathToLocationF(path.goalX, path.goalY, path.goalZ)
        elseif zombie.pathToLocation then
            zombie:pathToLocation(path.goalX, path.goalY, path.goalZ)
        end
        return true, "interact"
    end

    if (now - (tonumber(path.lastProgressAt) or 0)) >= 1200 then
        path.lastProgressAt = now
        path.lastIssueAt = now
        resetPathController(zombie)
        setWalkAnim(zombie, record, path.mode)
        if zombie.pathToLocationF then
            zombie:pathToLocationF(path.goalX, path.goalY, path.goalZ)
            return true, "repath"
        end
        if zombie.pathToLocation then
            zombie:pathToLocation(path.goalX, path.goalY, path.goalZ)
            return true, "repath"
        end
        if isSquareWalkable(path.goalX, path.goalY, path.goalZ) then
            zombie:setX(path.goalX)
            zombie:setY(path.goalY)
            zombie:setZ(path.goalZ)
            path.finished = true
            path.wasActive = false
            return true, "fallback_snap"
        end
    end

    return true, "waiting"
end

function PathService.Reset(zombie, record)
    if record and record.runtime then
        record.runtime.pathing = nil
    end
    resetPathController(zombie)
end

function PathService.MoveToward(record, zombie, targetX, targetY, targetZ, mode, stopDistance)
    local zx
    local zy
    local zz
    local dist
    stopDistance = tonumber(stopDistance) or 0.7
    if not zombie then
        return false, "no_body"
    end

    zx = zombie:getX()
    zy = zombie:getY()
    zz = zombie:getZ()
    dist = Core.Distance(zx, zy, targetX, targetY)
    if dist <= stopDistance and zz == targetZ then
        PathService.Reset(zombie, record)
        if mode == "crawl" then
            Animation.Apply(zombie, record, "Crawl")
        else
            Animation.Apply(zombie, record, mode == "sneak" and "SneakWalk" or "Idle")
        end
        return true, "arrived"
    end

    ensurePathRequest(zombie, record, targetX, targetY, targetZ, mode, stopDistance)
    return true, "path_requested"
end

function PathService.Pump(record, zombie)
    local ok
    local reason
    local runtime = record and record.runtime or nil
    local path = runtime and runtime.pathing or nil
    if not zombie or not path or path.goalX == nil or path.finished == true then
        return false, "no_active_path"
    end
    ok, reason = updatePathRequest(zombie, record)
    if reason == "arrived" or reason == "blocked" then
        if path.mode == "crawl" then
            Animation.Apply(zombie, record, "Crawl")
        else
            Animation.Apply(zombie, record, path.mode == "sneak" and "SneakWalk" or "Idle")
        end
    end
    return ok, reason
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
