PNC = PNC or {}
PNC.Health = PNC.Health or {}

local Health = PNC.Health
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry

function Health.Ensure(record)
    if not record.health then
        record.health = {
            current = Const.DEFAULT_HP_MAX,
            max = Const.DEFAULT_HP_MAX,
            state = "normal",
            lastDamageAt = 0,
            downedAt = 0,
        }
    end
    return record.health
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

    health.lastDamageAt = now

    if health.state == "downed" then
        Health.Kill(record, zombie, damageEvent and damageEvent.type or "downed_finish")
        return true
    end

    health.current = health.current - amount

    if health.current <= 0 then
        health.current = 1
        health.state = "downed"
        health.downedAt = now
        record.runtime.target = nil
        return true
    end

    return true
end

function Health.Update(record, zombie, now)
    local health = Health.Ensure(record)
    if record.alive == false then
        return
    end
    if health.state == "downed" and (now - (tonumber(health.downedAt) or 0)) >= Const.DOWNED_TIMEOUT_MS then
        Health.Kill(record, zombie, "downed_timeout")
    elseif zombie and zombie.setHealth then
        zombie:setHealth(Const.DEFAULT_ENGINE_BUFFER)
    end
end
