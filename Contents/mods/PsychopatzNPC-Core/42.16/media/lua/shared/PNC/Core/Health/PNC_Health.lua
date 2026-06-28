--[[
    PNC Health
    Single writer for NPC HP, incapacitation, revive windows, and death state.
    It also owns recent-damage timers that drive overhead combat visibility.
]]

PNC = PNC or {}
PNC.Health = PNC.Health or {}

local Health = PNC.Health
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry

local function resolvePathService()
    return PNC.PathService
end

local function resolveAnimation()
    return PNC.Animation
end

function Health.Ensure(record)
    if not record.health then
        record.health = {
            current = Const.DEFAULT_HP_MAX,
            max = Const.DEFAULT_HP_MAX,
            state = "normal",
            lastDamageAt = 0,
            downedAt = 0,
            recentDamageUntil = 0,
            reviveUntil = 0,
        }
    end
    if record.health.recentDamageUntil == nil then
        record.health.recentDamageUntil = 0
    end
    if record.health.reviveUntil == nil then
        record.health.reviveUntil = 0
    end
    return record.health
end

function Health.MarkRecentDamage(record, now)
    local health = Health.Ensure(record)
    local damageAt = tonumber(now) or Core.Now()
    health.lastDamageAt = damageAt
    health.recentDamageUntil = damageAt + Const.RECENT_DAMAGE_SHOW_MS
    record.runtime = record.runtime or {}
    record.runtime.inCombatUntil = math.max(
        tonumber(record.runtime.inCombatUntil or 0) or 0,
        damageAt + Const.DEBUG_COMBAT_HOLD_MS
    )
end

local function applyIncapacitatedLiveState(record, zombie)
    local Animation = resolveAnimation()
    local path = record and record.runtime and record.runtime.pathing or nil
    local moving = path and path.goalX ~= nil and path.finished ~= true and path.mode == "crawl"
    if not zombie then
        return
    end
    if zombie.setRunning then
        zombie:setRunning(false)
    end
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if zombie.setHealth then
        zombie:setHealth(Const.INCAPACITATED_ENGINE_BUFFER)
    end
    if Animation and Animation.ApplyDowned then
        Animation.ApplyDowned(zombie, record, moving == true)
    end
end

local function applyNormalLiveState(record, zombie)
    local Animation = resolveAnimation()
    if not zombie then
        return
    end
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if zombie.setHealth then
        zombie:setHealth(Const.DEFAULT_ENGINE_BUFFER)
    end
    if Animation and Animation.ClearDowned then
        Animation.ClearDowned(zombie)
    end
    if Animation and Animation.Apply then
        Animation.Apply(zombie, record, "Idle")
    end
end

local function refreshNormalLiveBuffer(zombie)
    if not zombie then
        return
    end
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    if zombie.setHealth then
        zombie:setHealth(Const.DEFAULT_ENGINE_BUFFER)
    end
end

function Health.EnterIncapacitated(record, zombie, reason)
    local health = Health.Ensure(record)
    local PathService = resolvePathService()
    local now = Core.Now()
    if not record or record.alive == false then
        return false
    end
    health.current = math.max(Const.INCAPACITATED_HP, 1)
    health.state = "incapacitated"
    health.downedAt = now
    health.incapacitatedReason = reason or "unknown"
    health.recentDamageUntil = now + Const.RECENT_DAMAGE_SHOW_MS
    health.reviveUntil = now + Const.INCAPACITATED_TIMEOUT_MS
    record.runtime.forceLive = true
    record.runtime.target = nil
    record.runtime.lastPathX = nil
    record.runtime.lastPathY = nil
    record.runtime.attackAction = nil
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    record.activeJob = "Incapacitated"
    record.activeBehavior = "Incapacitated"
    if PathService and PathService.Reset then
        PathService.Reset(zombie, record)
    end
    applyIncapacitatedLiveState(record, zombie)
    return true
end

function Health.Revive(record, zombie)
    local health = Health.Ensure(record)
    local revivedHP = math.min(health.max, math.max(Const.INCAPACITATED_HP, Const.REVIVE_HP))
    health.current = revivedHP
    health.state = "normal"
    health.downedAt = 0
    health.incapacitatedReason = nil
    health.reviveUntil = 0
    health.recentDamageUntil = Core.Now() + Const.RECENT_DAMAGE_SHOW_MS
    record.alive = true
    record.runtime.forceLive = false
    record.runtime.target = nil
    record.runtime.attackAction = nil
    record.runtime.inCombatUntil = 0
    applyNormalLiveState(record, zombie)
    return true
end

function Health.Recover(record, zombie)
    local health = Health.Ensure(record)
    health.current = health.max
    health.state = "normal"
    health.downedAt = 0
    health.incapacitatedReason = nil
    health.reviveUntil = 0
    health.recentDamageUntil = 0
    record.alive = true
    record.runtime.forceLive = false
    record.runtime.target = nil
    record.runtime.attackAction = nil
    record.runtime.inCombatUntil = 0
    applyNormalLiveState(record, zombie)
    return true
end

function Health.CanRevive(record, now)
    local health
    if not record then
        return false
    end
    health = Health.Ensure(record)
    now = tonumber(now) or Core.Now()
    return record
        and record.alive ~= false
        and health.state == "incapacitated"
        and (tonumber(health.reviveUntil) or 0) > now
end

function Health.ApplyDamageToPlayer(player, amount)
    local current
    if not player or not player.getHealth or not player.setHealth then
        return false
    end
    current = tonumber(player:getHealth()) or 1
    player:setHealth(math.max(0, current - (tonumber(amount) or 0) / 100))
    return true
end

function Health.Kill(record, zombie, reason)
    local health = Health.Ensure(record)
    health.current = 0
    health.state = "dead"
    health.reviveUntil = 0
    health.recentDamageUntil = Core.Now() + Const.RECENT_DAMAGE_SHOW_MS
    record.alive = false
    record.presenceState = Const.PRESENCE_CORPSE
    record.runtime.forceLive = false
    record.runtime.target = nil
    record.runtime.attackAction = nil
    record.runtime.lastPathX = nil
    record.runtime.lastPathY = nil
    record.deathReason = reason or "unknown"

    if zombie then
        if zombie.setHealth then
            zombie:setHealth(0)
        end
        if zombie.becomeCorpseSilently then
            zombie:becomeCorpseSilently()
        end
        Registry.UnregisterLiveZombie(record.id)
    end
end

function Health.ApplyDamage(record, zombie, damageEvent)
    local health = Health.Ensure(record)
    local amount = tonumber(damageEvent and damageEvent.amount or 0) or 0
    local now = Core.Now()

    if record.alive == false or amount <= 0 then
        return false
    end

    Health.MarkRecentDamage(record, now)
    if damageEvent and damageEvent.attackerKind == "zombie" then
        record.runtime.targetKind = "zombie"
        record.runtime.combatBlockReason = "taking_zombie_damage"
    end

    if health.state == "incapacitated" then
        if (now - (tonumber(health.downedAt) or 0)) < Const.INCAPACITATED_GRACE_MS then
            return false
        end
        Health.Kill(record, zombie, damageEvent and damageEvent.type or "incapacitated_finish")
        return true
    end

    health.current = health.current - amount

    if health.current <= 0 then
        return Health.EnterIncapacitated(record, zombie, damageEvent and damageEvent.type or "damage")
    end

    return true
end

function Health.Update(record, zombie, now)
    local health = Health.Ensure(record)
    if record.alive == false then
        return
    end
    if health.state == "incapacitated" then
        applyIncapacitatedLiveState(record, zombie)
        health.current = Const.INCAPACITATED_HP
        if now >= (tonumber(health.reviveUntil) or 0) then
            Health.Kill(record, zombie, "incapacitated_timeout")
        end
        return
    end
    if zombie then
        refreshNormalLiveBuffer(zombie)
    end
end
