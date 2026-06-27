PNC = PNC or {}
PNC.Combat = PNC.Combat or {}

local Combat = PNC.Combat
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Health = PNC.Health
local Animation = PNC.Animation
local Equipment = PNC.Equipment
local Perception = PNC.Perception

local function faceTarget(zombie, target)
    local liveTarget
    local zombieTarget
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
        return
    end
    if target.kind == "zombie" then
        zombieTarget = Perception and Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if zombieTarget and zombie.faceThisObject then
            zombie:faceThisObject(zombieTarget)
        end
    end
end

local function canAttack(record, now, cooldownMs)
    cooldownMs = cooldownMs or 1000
    return (now - (tonumber(record.runtime.lastAttackAt) or 0)) >= cooldownMs
end

local function resolveWeaponItem(record)
    local fullType = record and record.equipment and record.equipment.primaryFullType or nil
    if not fullType or not InventoryItemFactory or not InventoryItemFactory.CreateItem then
        return nil
    end
    return InventoryItemFactory.CreateItem(fullType)
end

local function applyDamageToZombie(record, attackerZombie, target, damage, attackType)
    local victim = target and target.zombieId and Perception.FindZombieByID(target.zombieId) or nil
    local fakeZombie
    local weaponItem
    local ok
    local health

    if not victim or victim:isDead() then
        return false, "invalid_zombie_target"
    end

    if victim.setAttackedBy then
        victim:setAttackedBy(attackerZombie or (getCell and getCell():getFakeZombieForHit() or nil))
    end

    if attackerZombie and victim.pathToCharacter then
        victim:pathToCharacter(attackerZombie)
    elseif attackerZombie and victim.pathToLocation then
        victim:pathToLocation(attackerZombie:getX(), attackerZombie:getY(), attackerZombie:getZ())
    end

    weaponItem = resolveWeaponItem(record)
    fakeZombie = getCell and getCell():getFakeZombieForHit() or nil
    if weaponItem and victim.Hit then
        ok = pcall(function()
            victim:Hit(weaponItem, fakeZombie or attackerZombie, (tonumber(damage) or 0) / 100, false, 1, false)
        end)
        if ok then
            return true, "hit_zombie"
        end
    end

    health = tonumber(victim:getHealth()) or 1
    victim:setHealth(health - ((tonumber(damage) or 0) / 100))
    if victim:getHealth() <= 0 then
        if victim.Kill then
            victim:Kill(attackerZombie or fakeZombie)
        elseif victim.setHealth then
            victim:setHealth(0)
        end
    end
    if attackType == "ranged" and victim.setHitReaction then
        victim:setHitReaction("ShotBelly")
    elseif victim.setHitReaction then
        victim:setHitReaction("HitReaction")
    end
    return true, "hit_zombie_fallback"
end

function Combat.TryMelee(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local cooldownMs = tonumber(profile.meleeCooldownMs) or 900
    local damage = tonumber(profile.meleeDamage) or 10
    local dist
    local targetRecord

    if not target then
        return false, "no_target"
    end
    if not canAttack(record, now, cooldownMs) then
        return false, "cooldown_active"
    end

    dist = math.sqrt(tonumber(target.distSq) or 0)
    if dist > Const.MELEE_RANGE then
        return false, "target_out_of_range"
    end

    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        if Health.ApplyDamageToPlayer(target.player, damage) then
            return true, "hit_player"
        end
        return false, "invalid_player_target"
    end

    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord then
            if Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = damage,
                type = "melee",
                attackerID = record.id,
                attackerKind = "npc",
            }) then
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        return false, "invalid_npc_target"
    end

    if target.kind == "zombie" then
        return applyDamageToZombie(record, zombie, target, damage, "melee")
    end

    return false, "unknown_target"
end

function Combat.TryRanged(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local cooldownMs = tonumber(profile.rangedCooldownMs) or 1800
    local damage = tonumber(profile.rangedDamage) or 7
    local dist
    local targetRecord
    local equipmentInfo = Equipment.Describe(record)

    if not target then
        return false, "no_target"
    end
    if equipmentInfo.combatModeResolved ~= "ranged" and equipmentInfo.combatModeResolved ~= "mixed" then
        return false, equipmentInfo.weaponStatus or "ranged_weapon_unavailable"
    end
    if not canAttack(record, now, cooldownMs) then
        return false, "cooldown_active"
    end

    dist = math.sqrt(tonumber(target.distSq) or 0)
    if dist > Const.RANGED_RANGE then
        return false, "target_out_of_range"
    end

    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        if Health.ApplyDamageToPlayer(target.player, damage) then
            return true, "hit_player"
        end
        return false, "invalid_player_target"
    end

    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord then
            if Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = damage,
                type = "ranged",
                attackerID = record.id,
                attackerKind = "npc",
            }) then
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        return false, "invalid_npc_target"
    end

    if target.kind == "zombie" then
        return applyDamageToZombie(record, zombie, target, damage, "ranged")
    end

    return false, "unknown_target"
end
