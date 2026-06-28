--[[
    PNC Combat Attack Actions
    Owns delayed hit windows, target re-resolution, zombie damage application,
    and active attack pumping so animations can complete before hits resolve.
]]

PNC = PNC or {}
PNC.Combat = PNC.Combat or {}
PNC.Combat.Internal = PNC.Combat.Internal or {}

local Combat = PNC.Combat
local Internal = Combat.Internal
local Core = PNC.Core
local Registry = PNC.Registry
local Health = PNC.Health
local Perception = PNC.Perception
local ZombieAggro = PNC.ZombieAggro
local Unarmed = PNC.CombatUnarmed
local Skills = PNC.Skills
local Stamina = PNC.Stamina
local Tactics = PNC.CombatTactics

local function captureTargetRef(target)
    if not target then
        return nil
    end
    return {
        kind = target.kind,
        id = target.id,
        onlineID = target.onlineID,
        username = target.username,
        zombieId = target.zombieId,
        x = target.x,
        y = target.y,
        z = target.z,
    }
end

local function resolveActionTarget(targetRef)
    local targetRecord
    local player
    local zombieTarget
    if not targetRef then
        return nil
    end
    if targetRef.kind == "player" then
        player = Core.ResolvePlayerByOnlineID(targetRef.onlineID) or Core.ResolvePlayerByUsername(targetRef.username)
        if not player then
            return nil
        end
        return {
            kind = "player",
            player = player,
            x = player:getX(),
            y = player:getY(),
            z = player:getZ(),
            distSq = 0,
        }
    end
    if targetRef.kind == "npc" then
        targetRecord = Registry.Get(targetRef.id)
        if not targetRecord or targetRecord.alive == false then
            return nil
        end
        return {
            kind = "npc",
            id = targetRecord.id,
            x = targetRecord.x,
            y = targetRecord.y,
            z = targetRecord.z,
            distSq = 0,
        }
    end
    if targetRef.kind == "zombie" then
        zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(targetRef.zombieId) or nil
        if not zombieTarget or zombieTarget:isDead() then
            return nil
        end
        return {
            kind = "zombie",
            zombieId = targetRef.zombieId,
            x = zombieTarget:getX(),
            y = zombieTarget:getY(),
            z = zombieTarget:getZ(),
            distSq = 0,
        }
    end
    return nil
end

function Internal.clearAttackAction(record)
    if record and record.runtime then
        record.runtime.attackAction = nil
    end
end

function Internal.buildAttackAction(record, target, attackKind, attackType, anim, damage, skillID, extra)
    local now = Core.Now()
    local timings = Internal.ATTACK_TIMINGS[attackKind] or Internal.ATTACK_TIMINGS.melee
    local action = {
        attackKind = attackKind,
        attackType = attackType,
        anim = anim,
        damage = damage,
        skillID = skillID,
        startedAt = now,
        hitAt = now + timings.hitDelay,
        finishAt = now + timings.duration,
        hitDone = false,
        target = captureTargetRef(target),
    }
    local key
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            action[key] = value
        end
    end
    record.runtime.attackAction = action
    return action
end

function Internal.applyDamageToZombie(record, attackerZombie, target, damage, attackType)
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

    weaponItem = Internal.resolveWeaponItem(record)
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
    end
    return true, applied and "hit_zombie" or "hit_zombie_fallback"
end

function Internal.applyAttackActionHit(record, zombie, action, target)
    local targetRecord
    local zombieTarget
    local attackApplied
    local attackReason
    if not action or not target then
        return false, "target_lost"
    end

    if action.attackKind == "shove" then
        zombieTarget = target.kind == "zombie" and Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if not zombieTarget then
            return false, "invalid_zombie_target"
        end
        if Unarmed and Unarmed.ApplyZombieShove and Unarmed.ApplyZombieShove(zombie, zombieTarget) then
            if Stamina and Stamina.SpendAttack then
                Stamina.SpendAttack(record, "melee", action.skillID or "Strength")
            end
            if Skills and Skills.AddXP then
                Skills.AddXP(record, "Strength", 2)
            end
            return true, "shoved_zombie"
        end
        return false, "zombie_shove_failed"
    end

    if action.attackKind == "ground" or action.attackType == "melee" then
        if target.kind == "player" then
            if Health.ApplyDamageToPlayer(target.player, action.damage) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "melee", action.skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, action.skillID or "Strength", action.attackKind == "ground" and 4 or 5)
                    Skills.AddXP(record, "Maintenance", 1)
                end
                return true, "hit_player"
            end
            return false, "invalid_player_target"
        end
        if target.kind == "npc" then
            targetRecord = Registry.Get(target.id)
            if not targetRecord then
                return false, "invalid_npc_target"
            end
            if Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = action.damage,
                type = "melee",
                attackerID = record.id,
                attackerKind = "npc",
            }) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "melee", action.skillID)
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, action.skillID or "Strength", 5)
                    Skills.AddXP(record, "Maintenance", 1)
                end
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        if target.kind == "zombie" then
            if Stamina and Stamina.SpendAttack then
                Stamina.SpendAttack(record, "melee", action.skillID)
            end
            if Skills and Skills.AddXP then
                Skills.AddXP(record, action.skillID or "Strength", action.attackKind == "ground" and 4 or 5)
                Skills.AddXP(record, "Maintenance", 1)
            end
            attackApplied, attackReason = Internal.applyDamageToZombie(record, zombie, target, action.damage, "melee")
            if attackApplied and action.attackKind == "melee" and Tactics and Tactics.ShouldPressureShove and Tactics.ShouldPressureShove(record) then
                zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
                if zombieTarget and Unarmed and Unarmed.ApplyZombieShove then
                    Unarmed.ApplyZombieShove(zombie, zombieTarget)
                end
            end
            return attackApplied, attackReason
        end
    end

    if action.attackType == "ranged" then
        if target.kind == "player" then
            if Health.ApplyDamageToPlayer(target.player, action.damage) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "ranged", action.skillID or "Aiming")
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
            if not targetRecord then
                return false, "invalid_npc_target"
            end
            if Health.ApplyDamage(targetRecord, Registry.GetLiveZombie(target.id), {
                amount = action.damage,
                type = "ranged",
                attackerID = record.id,
                attackerKind = "npc",
            }) then
                if Stamina and Stamina.SpendAttack then
                    Stamina.SpendAttack(record, "ranged", action.skillID or "Aiming")
                end
                if Skills and Skills.AddXP then
                    Skills.AddXP(record, "Aiming", 5)
                    Skills.AddXP(record, "Reloading", 2)
                end
                return true, "hit_npc"
            end
            return false, "npc_damage_rejected"
        end
        if target.kind == "zombie" then
            if Stamina and Stamina.SpendAttack then
                Stamina.SpendAttack(record, "ranged", action.skillID or "Aiming")
            end
            if Skills and Skills.AddXP then
                Skills.AddXP(record, "Aiming", 5)
                Skills.AddXP(record, "Reloading", 2)
            end
            return Internal.applyDamageToZombie(record, zombie, target, action.damage, "ranged")
        end
    end

    return false, "unknown_target"
end

function Combat.HasActiveAttack(record, now)
    local action = record and record.runtime and record.runtime.attackAction or nil
    now = tonumber(now) or Core.Now()
    return action ~= nil and now < (tonumber(action.finishAt) or 0)
end

function Combat.PumpAttackAction(record, zombie)
    local now = Core.Now()
    local action = record and record.runtime and record.runtime.attackAction or nil
    local target
    local bumpFinished
    if not action then
        return false, "no_attack"
    end
    if not zombie or record.alive == false then
        Internal.clearAttackAction(record)
        return false, "attack_cleared"
    end

    target = resolveActionTarget(action.target)
    if target then
        Internal.faceTarget(zombie, target)
    end

    if (not action.hitDone) and now >= (tonumber(action.hitAt) or 0) then
        action.hitDone = true
        action.lastResult, action.lastReason = Internal.applyAttackActionHit(record, zombie, action, target)
    end

    bumpFinished = zombie.getVariableBoolean and zombie:getVariableBoolean("BumpAnimFinished") or false
    if bumpFinished == true and action.hitDone ~= true then
        action.hitDone = true
        action.lastResult, action.lastReason = Internal.applyAttackActionHit(record, zombie, action, target)
    end
    if target == nil or bumpFinished == true or now >= (tonumber(action.finishAt) or 0) then
        Internal.clearAttackAction(record)
        return false, action.lastReason or (target and "attack_finished" or "target_lost")
    end

    return true, action.attackType == "ranged" and "attack_anim_ranged" or "attack_anim_melee"
end
