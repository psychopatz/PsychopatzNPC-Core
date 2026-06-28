--[[
    PNC Combat Melee
    Owns melee, shove, and downed-shove entry points. It decides which attack
    action to start and leaves hit timing to the attack action pump.
]]

PNC = PNC or {}
PNC.Combat = PNC.Combat or {}

local Combat = PNC.Combat
local Internal = PNC.Combat.Internal or {}
local Core = PNC.Core
local Const = PNC.Const
local Animation = PNC.Animation
local Equipment = PNC.Equipment
local Perception = PNC.Perception
local Unarmed = PNC.CombatUnarmed
local Skills = PNC.Skills
local Stamina = PNC.Stamina

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
    if Combat.HasActiveAttack and Combat.HasActiveAttack(record, now) then
        return false, "attack_in_progress"
    end
    if not Internal.canAttack(record, now, cooldownMs) then
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
    Internal.faceTarget(zombie, target)

    if target.kind == "zombie" then
        zombieTarget = Perception.FindZombieByID and Perception.FindZombieByID(target.zombieId) or nil
        if isBarehand and zombieTarget then
            if Unarmed and Unarmed.IsGroundTarget and Unarmed.IsGroundTarget(zombieTarget) then
                damage = tonumber(profile.unarmedGroundDamage) or Const.UNARMED_GROUND_DAMAGE
                anim = Unarmed and Unarmed.PlayGroundAttack and Unarmed.PlayGroundAttack(zombie, record, zombieTarget) or "PNC_Attack2HStamp"
                Internal.buildAttackAction(record, target, "ground", "melee", anim, damage, skillID)
                return true, "ground_attack_started"
            end
            if Unarmed and Unarmed.PlayShove then
                Unarmed.PlayShove(zombie, record, zombieTarget)
            end
            Internal.buildAttackAction(record, target, "shove", "melee", "PNC_Shove", tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE, "Strength")
            return true, "shove_started"
        end
    end

    if isBarehand then
        damage = tonumber(profile.unarmedDamage) or Const.UNARMED_DAMAGE
        if Animation and Animation.PlayBump then
            Animation.PlayBump(zombie, record, "PNC_Shove")
            anim = "PNC_Shove"
        end
    else
        Internal.playAttackSound(zombie, record)
        anim = Internal.triggerMeleeWeaponAnim(zombie, record, equipmentInfo)
    end
    Internal.buildAttackAction(record, target, "melee", "melee", anim or "PNC_Attack1H1", damage, skillID)
    return true, "melee_attack_started"
end

function Combat.TryDownedShove(record, zombie, target)
    local now = Core.Now()
    local zombieTarget
    if not target or not zombie then
        return false, "no_target"
    end
    if Combat.HasActiveAttack and Combat.HasActiveAttack(record, now) then
        return false, "attack_in_progress"
    end
    if not Internal.canAttack(record, now, Const.INCAP_SHOVE_COOLDOWN_MS) then
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
    Internal.faceTarget(zombie, target)
    if Unarmed and Unarmed.PlayShove then
        Unarmed.PlayShove(zombie, record, zombieTarget)
    end
    Internal.buildAttackAction(record, target, "shove", "melee", "PNC_Shove", Const.UNARMED_DAMAGE, "Strength")
    return true, "downed_shove_started"
end
