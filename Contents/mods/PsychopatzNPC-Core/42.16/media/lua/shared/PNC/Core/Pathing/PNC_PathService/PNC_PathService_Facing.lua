--[[
    PNC Path Service Facing
    Facing ownership and combat-facing lease helpers.
]]

PNC = PNC or {}
PNC.PathService = PNC.PathService or {}

local PathService = PNC.PathService
PathService.Internal = PathService.Internal or {}

local Internal = PathService.Internal
local Core = PNC.Core

function Internal.normalizeDirection(dx, dy)
    local len = math.sqrt((dx * dx) + (dy * dy))
    if len <= 0.0001 then
        return nil, nil
    end
    return dx / len, dy / len
end

function Internal.clearCombatFacing(lane)
    if not lane then
        return
    end
    lane.combatFacingUntil = 0
    lane.combatFacingX = nil
    lane.combatFacingY = nil
    lane.combatFacingZ = nil
    lane.combatFacingReason = nil
    if lane.facingOwner == "combat" then
        lane.facingOwner = lane.phase == "active" and "locomotion" or "idle"
    end
end

function Internal.clearExpiredCombatFacing(lane, now)
    if not lane then
        return
    end
    if (tonumber(lane.combatFacingUntil) or 0) <= (tonumber(now) or 0) then
        Internal.clearCombatFacing(lane)
    end
end

function Internal.shouldApplyFacing(lane, dirX, dirY, now, force)
    local previousX
    local previousY
    local dot
    if force == true or not lane then
        return true
    end
    previousX = tonumber(lane.lastFacingDirX)
    previousY = tonumber(lane.lastFacingDirY)
    if previousX and previousY then
        dot = (previousX * dirX) + (previousY * dirY)
        if dot >= 0.998 then
            return false
        end
        if dot >= Internal.FACE_SIMILAR_DOT and (now - (tonumber(lane.lastFacingAt) or 0)) < Internal.FACE_REAPPLY_INTERVAL_MS then
            return false
        end
    end
    return (now - (tonumber(lane.lastFacingAt) or 0)) >= Internal.FACE_REAPPLY_INTERVAL_MS
        or previousX == nil
        or previousY == nil
end

function Internal.applyFacingLocation(zombie, lane, faceX, faceY, now, owner, force)
    local dx
    local dy
    local lenSq
    local dirX
    local dirY
    if not zombie or faceX == nil or faceY == nil then
        return false
    end
    dx = tonumber(faceX) - zombie:getX()
    dy = tonumber(faceY) - zombie:getY()
    lenSq = (dx * dx) + (dy * dy)
    if lenSq < Internal.FACE_MIN_DISTANCE_SQ then
        return false
    end
    dirX, dirY = Internal.normalizeDirection(dx, dy)
    if not dirX or not Internal.shouldApplyFacing(lane, dirX, dirY, now, force) then
        return false
    end
    if zombie.faceLocationF then
        zombie:faceLocationF(zombie:getX() + dirX, zombie:getY() + dirY)
    end
    if lane then
        lane.lastFacingAt = now
        lane.lastFacingDirX = dirX
        lane.lastFacingDirY = dirY
        lane.lastFacingX = faceX
        lane.lastFacingY = faceY
        lane.facingOwner = owner or lane.facingOwner or "idle"
    end
    return true
end

function Internal.applyCombatFacing(zombie, lane, now, force)
    if not lane then
        return false
    end
    Internal.clearExpiredCombatFacing(lane, now)
    if (tonumber(lane.combatFacingUntil) or 0) <= now then
        return false
    end
    return Internal.applyFacingLocation(zombie, lane, lane.combatFacingX, lane.combatFacingY, now, "combat", force)
end

function PathService.RequestCombatFacing(record, zombie, target, leaseMs, reason)
    local lane
    local now
    local faceX
    local faceY
    local faceZ

    if not record or not zombie or not target then
        return false
    end

    lane = Internal.ensureMoveLane(record)
    if not lane then
        return false
    end

    faceX = target.x ~= nil and tonumber(target.x) or nil
    faceY = target.y ~= nil and tonumber(target.y) or nil
    faceZ = target.z ~= nil and tonumber(target.z) or zombie:getZ()
    if faceX == nil or faceY == nil then
        return false
    end

    now = Core.Now()
    lane.combatFacingX = faceX
    lane.combatFacingY = faceY
    lane.combatFacingZ = faceZ
    lane.combatFacingReason = reason or lane.combatFacingReason
    lane.combatFacingUntil = math.max(
        tonumber(lane.combatFacingUntil) or 0,
        now + math.max(60, tonumber(leaseMs) or Internal.COMBAT_FACING_DEFAULT_MS)
    )
    lane.facingOwner = "combat"
    Internal.applyFacingLocation(zombie, lane, faceX, faceY, now, "combat", true)
    return true
end

function PathService.ApplyTravelFacing(zombie, lane, faceX, faceY, now)
    now = tonumber(now) or Core.Now()
    if Internal.applyCombatFacing(zombie, lane, now, false) then
        return true
    end
    return Internal.applyFacingLocation(zombie, lane, faceX, faceY, now, "locomotion", false)
end
