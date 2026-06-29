--[[
    PNC Combat Zombie Reaction
    Owns short server-authoritative zombie hit and shove reactions triggered by
    NPC combat so reactions read clearly without relying on one-frame engine
    state flips alone.
]]

PNC = PNC or {}
PNC.CombatZombieReaction = PNC.CombatZombieReaction or {}

local ZombieReaction = PNC.CombatZombieReaction
local Core = PNC.Core
local ZombieAggro = PNC.ZombieAggro

local PUSH_INTERVAL_MS = 45
local DEFAULT_DURATION_MS = 220
local DEFAULT_PUSH_DURATION_MS = 150
local DEFAULT_PUSH_DISTANCE = 0.18
local DEFAULT_STEP_DISTANCE = 0.06

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

local function getReactionState(zombie)
    local modData = zombie and zombie.getModData and zombie:getModData() or nil
    return modData, modData and modData.PNC_CombatReaction or nil
end

local function clearReactionState(zombie, modData)
    if modData then
        modData.PNC_CombatReaction = nil
    end
    if zombie and zombie.setVariable then
        zombie:setVariable("NoLungeAttack", false)
    end
end

local function resolvePushDirection(attackerZombie, targetZombie)
    local dx
    local dy
    local len
    local forward
    if attackerZombie and targetZombie then
        dx = targetZombie:getX() - attackerZombie:getX()
        dy = targetZombie:getY() - attackerZombie:getY()
        len = math.sqrt((dx * dx) + (dy * dy))
        if len > 0.001 then
            return dx / len, dy / len
        end
    end
    forward = targetZombie and targetZombie.getForwardDirection and targetZombie:getForwardDirection() or nil
    if forward then
        dx = tonumber(forward:getX()) or 0
        dy = tonumber(forward:getY()) or 0
        len = math.sqrt((dx * dx) + (dy * dy))
        if len > 0.001 then
            return dx / len, dy / len
        end
    end
    return 1, 0
end

local function applyHitContext(attackerZombie, targetZombie, options)
    local ok
    local behind
    if not targetZombie then
        return
    end
    if targetZombie.setAttackedBy then
        targetZombie:setAttackedBy(attackerZombie or (getCell and getCell():getFakeZombieForHit() or nil))
    end
    if attackerZombie and targetZombie.setPlayerAttackPosition and targetZombie.testDotSide then
        targetZombie:setPlayerAttackPosition(targetZombie:testDotSide(attackerZombie))
    end
    if attackerZombie and targetZombie.setHitFromBehind and attackerZombie.isBehind then
        ok, behind = pcall(function()
            return attackerZombie:isBehind(targetZombie)
        end)
        if ok then
            targetZombie:setHitFromBehind(behind == true)
        end
    end
    if targetZombie.setHitForce then
        targetZombie:setHitForce(tonumber(options and options.hitForce) or 0.92)
    end
    if options and options.hitReaction and targetZombie.setHitReaction then
        targetZombie:setHitReaction(tostring(options.hitReaction))
    end
end

local function beginReaction(attackerZombie, targetZombie, options)
    local modData
    local state
    local dirX
    local dirY
    local now
    local durationMs
    local pushDurationMs
    local pushDistance
    local stepDistance

    if not targetZombie or targetZombie:isDead() then
        return false
    end

    modData, state = getReactionState(targetZombie)
    if not modData then
        return false
    end

    now = Core.Now()
    durationMs = math.max(80, tonumber(options and options.durationMs) or DEFAULT_DURATION_MS)
    pushDurationMs = math.max(0, tonumber(options and options.pushDurationMs) or DEFAULT_PUSH_DURATION_MS)
    pushDistance = math.max(0, tonumber(options and options.pushDistance) or DEFAULT_PUSH_DISTANCE)
    stepDistance = math.max(0.02, tonumber(options and options.stepDistance) or DEFAULT_STEP_DISTANCE)
    dirX, dirY = resolvePushDirection(attackerZombie, targetZombie)

    applyHitContext(attackerZombie, targetZombie, options)
    if options == nil or options.stagger ~= false then
        if targetZombie.setStaggerBack then
            pcall(targetZombie.setStaggerBack, targetZombie, true)
        end
        if targetZombie.setVariable then
            targetZombie:setVariable("NoLungeAttack", true)
        end
    end
    if options and options.heavy == true and options.knockdown == true and targetZombie.setKnockedDown then
        targetZombie:setKnockedDown(true)
    end

    state = state or {}
    state.kind = options and tostring(options.kind or "melee") or "melee"
    state.hitReaction = options and options.hitReaction or state.hitReaction or "HitReaction"
    state.expiresAt = math.max(tonumber(state.expiresAt) or 0, now + durationMs)
    state.pushExpiresAt = math.max(tonumber(state.pushExpiresAt) or 0, now + pushDurationMs)
    state.remainingPush = math.max(tonumber(state.remainingPush) or 0, pushDistance)
    state.stepDistance = math.max(tonumber(state.stepDistance) or 0, stepDistance)
    state.lastPushAt = tonumber(state.lastPushAt) or 0
    state.dirX = dirX
    state.dirY = dirY
    modData.PNC_CombatReaction = state

    if ZombieAggro and ZombieAggro.OnZombieProvoked and attackerZombie then
        ZombieAggro.OnZombieProvoked(targetZombie, attackerZombie)
    end
    return true
end

function ZombieReaction.Start(attackerZombie, targetZombie, options)
    return beginReaction(attackerZombie, targetZombie, options or {})
end

function ZombieReaction.ApplyWeaponHit(attackerZombie, targetZombie, weaponItem, scaledDamage, options)
    local fakeZombie
    local applied = false
    if not targetZombie or targetZombie:isDead() then
        return false
    end
    if weaponItem and targetZombie.Hit then
        fakeZombie = getCell and getCell():getFakeZombieForHit() or nil
        applied = pcall(function()
            targetZombie:Hit(weaponItem, fakeZombie or attackerZombie, tonumber(scaledDamage) or 0, false, 1, false)
        end)
    end
    beginReaction(attackerZombie, targetZombie, options or {})
    return applied == true
end

function ZombieReaction.Clear(targetZombie)
    local modData = targetZombie and targetZombie.getModData and targetZombie:getModData() or nil
    clearReactionState(targetZombie, modData)
end

function ZombieReaction.Pump(targetZombie, now)
    local modData
    local state
    local remainingPush
    local stepDistance
    local nx
    local ny
    local nz

    if not targetZombie or (targetZombie.isDead and targetZombie:isDead()) then
        ZombieReaction.Clear(targetZombie)
        return false
    end

    now = tonumber(now) or Core.Now()
    modData, state = getReactionState(targetZombie)
    if not state then
        return false
    end

    if now >= (tonumber(state.expiresAt) or 0) then
        clearReactionState(targetZombie, modData)
        return false
    end

    if targetZombie.setVariable then
        targetZombie:setVariable("NoLungeAttack", true)
    end
    if state.hitReaction and targetZombie.setHitReaction then
        targetZombie:setHitReaction(state.hitReaction)
    end

    remainingPush = math.max(0, tonumber(state.remainingPush) or 0)
    if remainingPush > 0
        and now < (tonumber(state.pushExpiresAt) or 0)
        and (now - (tonumber(state.lastPushAt) or 0)) >= PUSH_INTERVAL_MS
    then
        stepDistance = math.min(remainingPush, math.max(0.02, tonumber(state.stepDistance) or DEFAULT_STEP_DISTANCE))
        nz = targetZombie:getZ()
        nx = targetZombie:getX() + ((tonumber(state.dirX) or 0) * stepDistance)
        ny = targetZombie:getY() + ((tonumber(state.dirY) or 0) * stepDistance)
        if isSquareWalkable(nx, ny, nz) then
            targetZombie:setX(nx)
            targetZombie:setY(ny)
            state.remainingPush = math.max(0, remainingPush - stepDistance)
        else
            state.remainingPush = 0
        end
        state.lastPushAt = now
    end

    return true
end
