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
        }
    elseif record.health.recentDamageUntil == nil then
        record.health.recentDamageUntil = 0
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
    local PathService = resolvePathService()
    local Animation = resolveAnimation()
    if not zombie then
        return
    end
    if PathService and PathService.Reset then
        PathService.Reset(zombie, record)
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.setRunning then
        zombie:setRunning(false)
    end
    if zombie.setUseless then
        zombie:setUseless(true)
    end
    if zombie.setHealth then
        zombie:setHealth(Const.INCAPACITATED_ENGINE_BUFFER)
    end
    if Animation and Animation.Apply then
        Animation.Apply(zombie, record, "Idle")
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
    local now = Core.Now()
    if not record or record.alive == false then
        return false
    end
    health.current = math.max(Const.INCAPACITATED_HP, 1)
    health.state = "incapacitated"
    health.downedAt = now
    health.incapacitatedReason = reason or "unknown"
    health.recentDamageUntil = now + Const.RECENT_DAMAGE_SHOW_MS
    record.runtime.target = nil
    record.runtime.lastPathX = nil
    record.runtime.lastPathY = nil
    record.runtime.inCombatUntil = 0
    record.activeJob = "Incapacitated"
    record.activeBehavior = "Incapacitated"
    applyIncapacitatedLiveState(record, zombie)
    return true
end

function Health.Recover(record, zombie)
    local health = Health.Ensure(record)
    health.current = health.max
    health.state = "normal"
    health.downedAt = 0
    health.incapacitatedReason = nil
    health.recentDamageUntil = 0
    record.alive = true
    record.runtime.target = nil
    record.runtime.inCombatUntil = 0
    applyNormalLiveState(record, zombie)
    return true
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
    health.recentDamageUntil = Core.Now() + Const.RECENT_DAMAGE_SHOW_MS
    record.alive = false
    record.presenceState = Const.PRESENCE_CORPSE
    record.runtime.target = nil
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
        if (now - (tonumber(health.downedAt) or 0)) >= Const.INCAPACITATED_TIMEOUT_MS then
            Health.Kill(record, zombie, "incapacitated_timeout")
        end
        return
    end
    if zombie then
        refreshNormalLiveBuffer(zombie)
    end
end
