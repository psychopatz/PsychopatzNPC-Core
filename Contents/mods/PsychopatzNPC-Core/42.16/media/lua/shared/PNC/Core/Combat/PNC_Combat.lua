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
local ZombieAggro = PNC.ZombieAggro
local Unarmed = PNC.CombatUnarmed
local Skills = PNC.Skills
local Stamina = PNC.Stamina

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
    local item
    local _
    if not fullType then
        return nil
    end
    if Equipment.CreateItem then
        item, _ = Equipment.CreateItem(fullType)
    end
    return item
end

local function applyDamageToZombie(record, attackerZombie, target, damage, attackType)
    local victim = target and target.zombieId and Perception.FindZombieByID(target.zombieId) or nil
    local fakeZombie
    local weaponItem
    local ok
    local health
    local scaledDamage
    local applied = false

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
    if attackType == "ranged" then
        scaledDamage = math.max(0.12, (tonumber(damage) or 0) * 0.06)
    else
        scaledDamage = math.max(0.18, (tonumber(damage) or 0) * 0.08)
    end
    if weaponItem and victim.Hit then
        ok = pcall(function()
            victim:Hit(weaponItem, fakeZombie or attackerZombie, scaledDamage, false, 1, false)
        end)
        if ok then
            applied = true
        end
    end

    if not applied then
        health = tonumber(victim:getHealth()) or 1
        victim:setHealth(health - scaledDamage)
        if victim:getHealth() <= 0 then
            if victim.Kill then
                victim:Kill(attackerZombie or fakeZombie)
            elseif victim.setHealth then
                victim:setHealth(0)
            end
        end
    end
    if attackType == "ranged" and victim.setHitReaction then
        victim:setHitReaction("ShotBelly")
    elseif victim.setHitReaction then
        victim:setHitReaction("HitReaction")
    end
    if ZombieAggro and ZombieAggro.OnZombieProvoked and attackerZombie then
        ZombieAggro.OnZombieProvoked(victim, attackerZombie)
    elseif attackerZombie and victim.pathToCharacter then
        victim:pathToCharacter(attackerZombie)
    end
    return true, applied and "hit_zombie" or "hit_zombie_fallback"
end

function Combat.TryMelee(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local damage = tonumber(profile.meleeDamage) or 10
    local dist
    local targetRecord
    local equipmentInfo = Equipment.Describe(record)
    local zombieTarget
    local isBarehand = equipmentInfo.primaryType == "barehand"
    local cooldownMs = isBarehand and (tonumber(profile.unarmedCooldownMs) or Const.UNARMED_COOLDOWN_MS) or (tonumber(profile.meleeCooldownMs) or 900)
    local skillID = Skills and Skills.ResolveWeaponSkill and Skills.ResolveWeaponSkill(record, record.equipment and record.equipment.primaryFullType, "melee") or "Strength"

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
    if Stamina and Stamina.CanSpendAttack and not Stamina.CanSpendAttack(record, "melee", skillID) then
        return false, "stamina_exhausted"
    end

    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        if equipmentInfo.primaryType == "barehand" and Animation and Animation.PlayBump then
            Animation.PlayBump(zombie, record, "Shove")
        end
        if isBarehand then
            damage = tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE
        end
        if Health.ApplyDamageToPlayer(target.player, damage) then
            if Stamina and Stamina.SpendAttack then
                Stamina.SpendAttack(record, "melee", skillID)
            end
            if Skills and Skills.AddXP then
                Skills.AddXP(record, skillID, 5)
                Skills.AddXP(record, "Maintenance", 1)
            end
            return true, "hit_player"
        end
        return false, "invalid_player_target"
    end

    if target.kind == "npc" then
        targetRecord = Registry.Get(target.id)
        if targetRecord then
            if equipmentInfo.primaryType == "barehand" and Animation and Animation.PlayBump then
                Animation.PlayBump(zombie, record, "Shove")
            end
            if isBarehand then
                damage = tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE
            end
            if Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = damage,
                type = "melee",
                attackerID = record.id,
                attackerKind = "npc",
            }) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "melee", skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, skillID, 5)
                    Skills.AddXP(record, "Maintenance", 1)
                end
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        return false, "invalid_npc_target"
    end

    if target.kind == "zombie" then
        zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if equipmentInfo.primaryType == "barehand" and zombieTarget then
            if Unarmed and Unarmed.IsGroundTarget and Unarmed.IsGroundTarget(zombieTarget) then
                damage = tonumber(profile.unarmedGroundDamage) or Const.UNARMED_GROUND_DAMAGE
                if Unarmed.PlayGroundAttack then
                    Unarmed.PlayGroundAttack(zombie, record, zombieTarget)
                end
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "melee", skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, skillID, 4)
                    Skills.AddXP(record, "Maintenance", 1)
                end
                return applyDamageToZombie(record, zombie, target, damage, "melee")
            end
            if Unarmed and Unarmed.PlayShove then
                Unarmed.PlayShove(zombie, record, zombieTarget)
            end
            if Unarmed and Unarmed.ApplyZombieShove and Unarmed.ApplyZombieShove(zombie, zombieTarget) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "melee", skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, "Strength", 2)
                end
                return true, "shoved_zombie"
            end
            return false, "zombie_shove_failed"
        end
        if Stamina and Stamina.SpendAttack then
            Stamina.SpendAttack(record, "melee", skillID)
        end
        if Skills and Skills.AddXP then
            Skills.AddXP(record, skillID, 5)
            Skills.AddXP(record, "Maintenance", 1)
        end
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
    local skillID = "Aiming"

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
    if Stamina and Stamina.CanSpendAttack and not Stamina.CanSpendAttack(record, "ranged", skillID) then
        return false, "stamina_exhausted"
    end

    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if zombie then
        Animation.Apply(zombie, record, "Attack")
    end

    if target.kind == "player" then
        if Health.ApplyDamageToPlayer(target.player, damage) then
            if Stamina and Stamina.SpendAttack then
                Stamina.SpendAttack(record, "ranged", skillID)
            end
            if Skills and Skills.AddXP then
                Skills.AddXP(record, "Aiming", 5)
                Skills.AddXP(record, "Reloading", 2)
            end
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
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "ranged", skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, "Aiming", 5)
                    Skills.AddXP(record, "Reloading", 2)
                end
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        return false, "invalid_npc_target"
    end

    if target.kind == "zombie" then
        if Stamina and Stamina.SpendAttack then
            Stamina.SpendAttack(record, "ranged", skillID)
        end
        if Skills and Skills.AddXP then
            Skills.AddXP(record, "Aiming", 5)
            Skills.AddXP(record, "Reloading", 2)
        end
        return applyDamageToZombie(record, zombie, target, damage, "ranged")
    end

    return false, "unknown_target"
end

function Combat.TryDownedShove(record, zombie, target)
    local now = Core.Now()
    local zombieTarget
    if not target or not zombie then
        return false, "no_target"
    end
    if not canAttack(record, now, Const.INCAP_SHOVE_COOLDOWN_MS) then
        return false, "cooldown_active"
    end
    if math.sqrt(tonumber(target.distSq) or 0) > Const.INCAP_SHOVE_RANGE then
        return false, "target_out_of_range"
    end
    if Stamina and Stamina.CanSpendAttack and not Stamina.CanSpendAttack(record, "downed_shove", "Strength") then
        return false, "stamina_exhausted"
    end
    zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
    if not zombieTarget then
        return false, "invalid_zombie_target"
    end
    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if Unarmed and Unarmed.PlayShove then
        Unarmed.PlayShove(zombie, record, zombieTarget)
    end
    if Unarmed and Unarmed.ApplyZombieShove and Unarmed.ApplyZombieShove(zombie, zombieTarget) then
        if Stamina and Stamina.SpendAttack then
            Stamina.SpendAttack(record, "downed_shove", "Strength")
        end
        if Skills and Skills.AddXP then
            Skills.AddXP(record, "Strength", 2)
            Skills.AddXP(record, "Fitness", 1)
        end
        return true, "downed_shove"
    end
    return false, "downed_shove_failed"
end
