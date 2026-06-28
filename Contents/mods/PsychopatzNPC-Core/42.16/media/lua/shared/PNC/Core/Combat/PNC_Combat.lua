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

local MELEE_BUMP_TYPES = {
    onehanded = { "Attack1H1", "Attack1H2", "Attack1H3", "Attack1H4", "Attack1H5" },
    twohanded = { "Attack2H1", "Attack2H2", "Attack2H3", "Attack2H4" },
    spear = { "AttackS1", "AttackS2" },
    knife = { "AttackKnife" },
}

local RANGED_BUMP_TYPES = {
    handgun = { "AttackPistol" },
    rifle = { "AttackRifle" },
}

local ATTACK_TIMINGS = {
    melee = { hitDelay = 260, duration = 720 },
    ranged = { hitDelay = 180, duration = 620 },
    shove = { hitDelay = 130, duration = 480 },
    ground = { hitDelay = 240, duration = 760 },
}

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

local function resolveMeleeAnimFamily(record, equipmentInfo)
    local fullType = string.lower(tostring(record and record.equipment and record.equipment.primaryFullType or ""))
    if fullType ~= "" and (
        string.find(fullType, "knife", 1, true)
        or string.find(fullType, "dagger", 1, true)
        or string.find(fullType, "shiv", 1, true)
        or string.find(fullType, "scalpel", 1, true)
    ) then
        return "knife"
    end
    if equipmentInfo and (equipmentInfo.primaryType == "twohanded" or equipmentInfo.primaryType == "spear") then
        return equipmentInfo.primaryType
    end
    return "onehanded"
end

local function triggerMeleeWeaponAnim(zombie, record, equipmentInfo)
    local options = MELEE_BUMP_TYPES[resolveMeleeAnimFamily(record, equipmentInfo)] or MELEE_BUMP_TYPES.onehanded
    local anim
    if not zombie or not Animation or not Animation.PlayBump or not options or #options <= 0 then
        return nil
    end
    anim = options[ZombRand(#options) + 1]
    Animation.PlayBump(zombie, record, anim)
    return anim
end

local function triggerRangedWeaponAnim(zombie, record, equipmentInfo)
    local family = equipmentInfo and equipmentInfo.primaryType == "rifle" and "rifle" or "handgun"
    local options = RANGED_BUMP_TYPES[family] or RANGED_BUMP_TYPES.handgun
    local anim
    if not zombie or not Animation or not Animation.PlayBump or not options or #options <= 0 then
        return nil
    end
    anim = options[ZombRand(#options) + 1]
    Animation.PlayBump(zombie, record, anim)
    return anim
end

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

local function clearAttackAction(record)
    if record and record.runtime then
        record.runtime.attackAction = nil
    end
end

local function buildAttackAction(record, target, attackKind, attackType, anim, damage, skillID, extra)
    local now = Core.Now()
    local timings = ATTACK_TIMINGS[attackKind] or ATTACK_TIMINGS.melee
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
    if type(extra) == "table" then
        local key
        for key, value in pairs(extra) do
            action[key] = value
        end
    end
    record.runtime.attackAction = action
    return action
end

local function playAttackSound(zombie, record)
    local item
    local emitter
    local swingSound
    if not zombie or not zombie.getEmitter then
        return
    end
    item = resolveWeaponItem(record)
    emitter = zombie:getEmitter()
    swingSound = item and item.getSwingSound and item:getSwingSound() or nil
    if swingSound and swingSound ~= "" and emitter and emitter.playSound then
        emitter:playSound(swingSound)
    end
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
    end
    return true, applied and "hit_zombie" or "hit_zombie_fallback"
end

local function applyAttackActionHit(record, zombie, action, target)
    local targetRecord
    if not action or not target then
        return false, "target_lost"
    end

    if action.attackKind == "shove" then
        local zombieTarget = target.kind == "zombie" and Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
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
            return applyDamageToZombie(record, zombie, target, action.damage, "melee")
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
            return applyDamageToZombie(record, zombie, target, action.damage, "ranged")
        end
    end

    return false, "unknown_target"
end

local function hasActiveAttack(record, now)
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
        clearAttackAction(record)
        return false, "attack_cleared"
    end

    target = resolveActionTarget(action.target)
    if target then
        faceTarget(zombie, target)
    end

    if (not action.hitDone) and now >= (tonumber(action.hitAt) or 0) then
        action.hitDone = true
        action.lastResult, action.lastReason = applyAttackActionHit(record, zombie, action, target)
    end

    bumpFinished = zombie.getVariableBoolean and zombie:getVariableBoolean("BumpAnimFinished") or false
    if bumpFinished == true and action.hitDone ~= true then
        action.hitDone = true
        action.lastResult, action.lastReason = applyAttackActionHit(record, zombie, action, target)
    end
    if target == nil or bumpFinished == true or now >= (tonumber(action.finishAt) or 0) then
        clearAttackAction(record)
        return false, action.lastReason or (target and "attack_finished" or "target_lost")
    end

    return true, action.attackType == "ranged" and "attack_anim_ranged" or "attack_anim_melee"
end

function Combat.TryMelee(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local damage = tonumber(profile.meleeDamage) or 10
    local dist
    local equipmentInfo = Equipment.Describe(record)
    local zombieTarget
    local anim
    local isBarehand = equipmentInfo.primaryType == "barehand"
    local cooldownMs = isBarehand and (tonumber(profile.unarmedCooldownMs) or Const.UNARMED_COOLDOWN_MS) or (tonumber(profile.meleeCooldownMs) or 900)
    local skillID = Skills and Skills.ResolveWeaponSkill and Skills.ResolveWeaponSkill(record, record.equipment and record.equipment.primaryFullType, "melee") or "Strength"
    local skillLevel = Skills and Skills.GetLevel and Skills.GetLevel(record, skillID) or 0
    local strengthLevel = Skills and Skills.GetLevel and Skills.GetLevel(record, "Strength") or 0

    if not target then
        return false, "no_target"
    end
    if hasActiveAttack(record, now) then
        return false, "attack_in_progress"
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

    damage = damage * (0.9 + math.min(skillLevel, 8) * 0.04 + math.min(strengthLevel, 6) * 0.02)
    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)

    if target.kind == "zombie" then
        zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if equipmentInfo.primaryType == "barehand" and zombieTarget then
            if Unarmed and Unarmed.IsGroundTarget and Unarmed.IsGroundTarget(zombieTarget) then
                damage = tonumber(profile.unarmedGroundDamage) or Const.UNARMED_GROUND_DAMAGE
                anim = Unarmed and Unarmed.PlayGroundAttack and Unarmed.PlayGroundAttack(zombie, record, zombieTarget) or "Attack2HStamp"
                buildAttackAction(record, target, "ground", "melee", anim, damage, skillID)
                return true, "ground_attack_started"
            end
            if Unarmed and Unarmed.PlayShove then
                Unarmed.PlayShove(zombie, record, zombieTarget)
            end
            buildAttackAction(record, target, "shove", "melee", "Shove", tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE, "Strength")
            return true, "shove_started"
        end
    end

    if isBarehand then
        damage = tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE
        if Animation and Animation.PlayBump then
            Animation.PlayBump(zombie, record, "Shove")
            anim = "Shove"
        end
    else
        playAttackSound(zombie, record)
        anim = triggerMeleeWeaponAnim(zombie, record, equipmentInfo)
    end
    buildAttackAction(record, target, "melee", "melee", anim or "Attack1H1", damage, skillID)
    return true, "melee_attack_started"
end

function Combat.TryRanged(record, zombie, target)
    local now = Core.Now()
    local profile = record.combatProfile or {}
    local cooldownMs = tonumber(profile.rangedCooldownMs) or 1800
    local damage = tonumber(profile.rangedDamage) or 7
    local dist
    local equipmentInfo = Equipment.Describe(record)
    local skillID = "Aiming"
    local aimingLevel = Skills and Skills.GetLevel and Skills.GetLevel(record, "Aiming") or 0
    local anim

    if not target then
        return false, "no_target"
    end
    if equipmentInfo.combatModeResolved ~= "ranged" and equipmentInfo.combatModeResolved ~= "mixed" then
        return false, equipmentInfo.weaponStatus or "ranged_weapon_unavailable"
    end
    if hasActiveAttack(record, now) then
        return false, "attack_in_progress"
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

    damage = damage * (0.9 + math.min(aimingLevel, 8) * 0.05)
    record.runtime.lastAttackAt = now
    record.runtime.inCombatUntil = now + Const.DEBUG_COMBAT_HOLD_MS
    faceTarget(zombie, target)
    if zombie then
        playAttackSound(zombie, record)
        anim = triggerRangedWeaponAnim(zombie, record, equipmentInfo)
    end
    buildAttackAction(record, target, "ranged", "ranged", anim or "AttackPistol", damage, skillID)
    return true, "ranged_attack_started"
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
