PNC = PNC or {}
PNC.Combat = PNC.Combat or {}

local Combat = PNC.Combat
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Health = PNC.Health
local Animation = PNC.Animation

local function faceTarget(zombie, target)
    local liveTarget
    if not zombie or not target then
        return
    end
    if target.kind == "player" and target.player then
        if zombie.faceThisObject then
            zombie:faceThisObject(target.player)
        end
        return
    end
    if target.kind == "npc" then
        liveTarget = Registry.GetLiveZombie(target.id)
        if liveTarget then
            if zombie.faceThisObject then
                zombie:faceThisObject(liveTarget)
            end
        end
    end
end

local function canAttack(record, now, cooldownMs)
    cooldownMs = cooldownMs or 1000
    return (now - (tonumber(record.runtime.lastAttackAt) or 0)) >= cooldownMs
end

function Combat.TryMelee(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local cooldownMs = tonumber(profile.meleeCooldownMs) or 900
    local damage = tonumber(profile.meleeDamage) or 10
    local dist
    local targetRecord

    if not target or not canAttack(record, now, cooldownMs) then
        return false
    end

    dist = math.sqrt(tonumber(target.distSq) or 0)
    if dist > Const.MELEE_RANGE then
        return false
    end

    record.runtime.lastAttackAt = now
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        return Health.ApplyDamageToPlayer(target.player, damage)
    end

    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord then
            return Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = damage,
                type = "melee",
                attackerID = record.id,
            })
        end
    end
    return false
end

function Combat.TryRanged(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local cooldownMs = tonumber(profile.rangedCooldownMs) or 1800
    local damage = tonumber(profile.rangedDamage) or 7
    local dist
    local targetRecord

    if not target or not canAttack(record, now, cooldownMs) then
        return false
    end

    dist = math.sqrt(tonumber(target.distSq) or 0)
    if dist > Const.RANGED_RANGE then
        return false
    end

    record.runtime.lastAttackAt = now
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        return Health.ApplyDamageToPlayer(target.player, damage)
    end

    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord then
            return Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = damage,
                type = "ranged",
                attackerID = record.id,
            })
        end
    end
    return false
end
