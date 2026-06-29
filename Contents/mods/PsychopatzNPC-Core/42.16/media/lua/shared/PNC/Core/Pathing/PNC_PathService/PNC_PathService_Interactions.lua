--[[
    PNC Path Service Interactions
    Door and window handling plus special-action suppression helpers.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

local Internal = PathService.Internal
local Animation = PNC.Animation

function Internal.rememberSpecialAction(lane, key, now)
    if not lane then
        return
    end
    lane.lastSpecialActionKey = key
    lane.lastSpecialActionAt = now
end

function Internal.shouldSuppressSpecialAction(lane, key, now)
    if not lane or not key then
        return false
    end
    return lane.lastSpecialActionKey == key and (now - (tonumber(lane.lastSpecialActionAt) or 0)) < Internal.SPECIAL_ACTION_COOLDOWN_MS
end

function Internal.openDoorForNPC(zombie, object)
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

function Internal.tryDoorOrWindowInteraction(zombie, record, lane, goalX, goalY, goalZ)
    local cell
    local now
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
    local objectSquare
    local facingSatisfied
    local targetDx
    local targetDy
    local candidatesByGoal
    local actionKey
    local fromPoint
    local destSquare

    if not zombie or not getCell then
        return false, nil
    end

    now = Internal.Core.Now()
    cell = getCell()
    zx = math.floor(zombie:getX())
    zy = math.floor(zombie:getY())
    zz = zombie:getZ()
    fromPoint = Internal.describePoint(string.format("%.2f", zombie:getX()), string.format("%.2f", zombie:getY()), zz)
    fd = zombie:getForwardDirection()
    fdx = Internal.roundHalf(fd:getX())
    fdy = Internal.roundHalf(fd:getY())
    targetDx = Internal.roundHalf((goalX or zombie:getX()) - zombie:getX())
    targetDy = Internal.roundHalf((goalY or zombie:getY()) - zombie:getY())

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
                        objectSquare = object:getSquare()
                        actionKey = "door:" .. Internal.describeSquare(objectSquare)
                        if Internal.shouldSuppressSpecialAction(lane, actionKey, now) then
                            return false, nil
                        end
                        if Internal.openDoorForNPC(zombie, object) then
                            Internal.rememberSpecialAction(lane, actionKey, now)
                            Internal.logMoveWarning(record, zombie, lane, "door_open", "door_open", "from=" .. fromPoint .. " object=" .. Internal.describeSquare(objectSquare) .. " goal=" .. Internal.describePoint(goalX, goalY, goalZ))
                            return true, "door_open"
                        end
                    end
                    if instanceof(object, "IsoWindow") then
                        if (not facingSatisfied) and zombie.faceThisObject then
                            zombie:faceThisObject(object)
                            facingSatisfied = true
                        end
                    end
                    if instanceof(object, "IsoWindow") and facingSatisfied then
                        objectSquare = object:getSquare()
                        if (not object:IsOpen()) and (not object:isSmashed()) and (not object:isPermaLocked()) then
                            actionKey = "window_open:" .. Internal.describeSquare(objectSquare)
                            if Internal.shouldSuppressSpecialAction(lane, actionKey, now) then
                                return false, nil
                            end
                            object:ToggleWindow(zombie)
                            Internal.rememberSpecialAction(lane, actionKey, now)
                            Internal.logMoveWarning(record, zombie, lane, "window_open", "window_open", "from=" .. fromPoint .. " object=" .. Internal.describeSquare(objectSquare) .. " goal=" .. Internal.describePoint(goalX, goalY, goalZ))
                            return true, "window_open"
                        end
                        if object:canClimbThrough(zombie) then
                            actionKey = "window_climb:" .. Internal.describeSquare(objectSquare)
                            if Internal.shouldSuppressSpecialAction(lane, actionKey, now) then
                                return false, nil
                            end
                            if object.getOppositeSquare then
                                destSquare = object:getOppositeSquare()
                            else
                                destSquare = nil
                            end
                            if not destSquare or not Internal.isSquareWalkable(destSquare:getX() + 0.5, destSquare:getY() + 0.5, destSquare:getZ()) then
                                return false, nil
                            end
                            if Animation and Animation.PlayBump then
                                Animation.PlayBump(zombie, record, "ClimbWindow")
                            elseif zombie.setBumpType then
                                zombie:setBumpType("ClimbWindow")
                            end
                            zombie:setX(destSquare:getX() + 0.5)
                            zombie:setY(destSquare:getY() + 0.5)
                            zombie:setZ(destSquare:getZ())
                            Internal.syncRecordPosition(record, zombie)
                            Internal.rememberSpecialAction(lane, actionKey, now)
                            lane.specialMoveUntil = now + 450
                            lane.specialAnim = "ClimbWindow"
                            Internal.logMoveWarning(
                                record,
                                zombie,
                                lane,
                                "window_climb",
                                "window_climb",
                                "from=" .. fromPoint .. " object=" .. Internal.describeSquare(objectSquare) .. " to=" .. Internal.describeSquare(destSquare) .. " goal=" .. Internal.describePoint(goalX, goalY, goalZ)
                            )
                            return true, "window_climb"
                        end
                    end
                end
            end
        end
    end

    return false, nil
end
