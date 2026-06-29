--[[
    PNC Fake Locomotion
    Server-authoritative embodied movement for live NPC bodies. It keeps zombie
    AI disabled and advances bodies by small controlled steps so behaviors can
    share one locomotion authority in both singleplayer and multiplayer.
]]

PNC = PNC or {}
PNC.FakeLocomotion = PNC.FakeLocomotion or {}

local FakeLocomotion = PNC.FakeLocomotion
local Core = PNC.Core
local LiveBodyControl = PNC.LiveBodyControl

local MAX_STEP_DELTA_MS = 120
local MIN_STEP_INTERVAL_MS = 35
local WALK_ANIM_SPEED = 1.04
local MODE_SPEEDS = {
    crawl = 0.30,
    run = 2.10,
    sneak = 0.48,
    walk = 0.76,
}

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

local function buildCandidate(label, x, y, z)
    return {
        label = label,
        x = x,
        y = y,
        z = z,
    }
end

local function getSpeedForMode(mode)
    mode = tostring(mode or "walk")
    return MODE_SPEEDS[mode] or MODE_SPEEDS.walk
end

function FakeLocomotion.GetModeSpeed(mode)
    return getSpeedForMode(mode)
end

function FakeLocomotion.ComputeAnimSpeed(mode)
    local speed = getSpeedForMode(mode)
    local ratio = speed / math.max(0.01, MODE_SPEEDS.walk)
    local animSpeed = WALK_ANIM_SPEED * math.sqrt(math.max(0.2, ratio))
    if mode == "run" then
        return math.max(1.40, math.min(1.72, animSpeed))
    end
    if mode == "sneak" then
        return math.max(0.80, math.min(0.92, animSpeed))
    end
    if mode == "crawl" then
        return math.max(0.68, math.min(0.78, animSpeed))
    end
    return math.max(0.98, math.min(1.12, animSpeed))
end

local function computeStepDistance(lane, mode, now)
    local lastStepAt = tonumber(lane and lane.lastStepAt or 0) or 0
    local deltaMs
    if lastStepAt <= 0 then
        return math.max(0.03, getSpeedForMode(mode) * 0.05), 50
    end
    deltaMs = math.max(0, now - lastStepAt)
    if deltaMs < MIN_STEP_INTERVAL_MS then
        return 0, deltaMs
    end
    deltaMs = math.min(deltaMs, MAX_STEP_DELTA_MS)
    return math.max(0.02, getSpeedForMode(mode) * (deltaMs / 1000)), deltaMs
end

local function buildStepCandidates(zx, zy, zz, goal, stepDistance)
    local dx = goal.x - zx
    local dy = goal.y - zy
    local len = math.sqrt((dx * dx) + (dy * dy))
    local ux
    local uy
    local px
    local py
    if len <= 0.0001 then
        return {}
    end
    ux = dx / len
    uy = dy / len
    px = -uy
    py = ux
    return {
        buildCandidate("direct", zx + (ux * stepDistance), zy + (uy * stepDistance), goal.z),
        buildCandidate("x_only", zx + (ux * stepDistance), zy, goal.z),
        buildCandidate("y_only", zx, zy + (uy * stepDistance), goal.z),
        buildCandidate("slide_left", zx + ((ux + (px * 0.55)) * stepDistance), zy + ((uy + (py * 0.55)) * stepDistance), goal.z),
        buildCandidate("slide_right", zx + ((ux - (px * 0.55)) * stepDistance), zy + ((uy - (py * 0.55)) * stepDistance), goal.z),
        buildCandidate("hard_left", zx + (px * stepDistance), zy + (py * stepDistance), goal.z),
        buildCandidate("hard_right", zx - (px * stepDistance), zy - (py * stepDistance), goal.z),
    }
end

function FakeLocomotion.PrepareBody(zombie, lane, now)
    local resolvedMode = lane and lane.resolvedMode or lane and lane.mode or "walk"
    if not zombie then
        return
    end
    if LiveBodyControl and LiveBodyControl.ApplyHumanizedBodyFlags then
        LiveBodyControl.ApplyHumanizedBodyFlags(zombie)
    end
    if LiveBodyControl and LiveBodyControl.TrySilenceEmitter then
        LiveBodyControl.TrySilenceEmitter(zombie, lane, now)
    end
    if zombie.setRunning then
        zombie:setRunning(tostring(resolvedMode) == "run")
    end
    if zombie.setUseless then
        zombie:setUseless(true)
    end
end

function FakeLocomotion.StepTowardGoal(zombie, record, lane, goal, now)
    local stepDistance
    local zx
    local zy
    local candidates
    local i
    local candidate
    if not zombie or not record or not lane or not goal then
        return false, "invalid", 0
    end
    stepDistance = computeStepDistance(lane, lane and lane.resolvedMode or lane.mode or goal.mode, now)
    if stepDistance <= 0 then
        return false, "throttle", 0
    end
    zx = zombie:getX()
    zy = zombie:getY()
    candidates = buildStepCandidates(zx, zy, goal.z, goal, stepDistance)
    for i = 1, #candidates do
        candidate = candidates[i]
        if isSquareWalkable(candidate.x, candidate.y, candidate.z) then
            if PNC.PathService and PNC.PathService.ApplyTravelFacing then
                PNC.PathService.ApplyTravelFacing(zombie, lane, candidate.x, candidate.y, now)
            elseif zombie.faceLocationF then
                zombie:faceLocationF(candidate.x, candidate.y)
            end
            zombie:setX(candidate.x)
            zombie:setY(candidate.y)
            zombie:setZ(candidate.z)
            record.x = candidate.x
            record.y = candidate.y
            record.z = candidate.z
            lane.lastStepAt = now
            lane.lastStepDistance = stepDistance
            lane.lastStepLabel = candidate.label
            lane.lastProgressAt = now
            lane.lastX = candidate.x
            lane.lastY = candidate.y
            lane.lastZ = candidate.z
            return true, candidate.label, stepDistance
        end
    end
    lane.lastStepAt = now
    lane.lastStepDistance = 0
    lane.lastStepLabel = "blocked"
    return false, "blocked", stepDistance
end
