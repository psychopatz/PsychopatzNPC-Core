--[[
    PNC Combat Ranged
    Owns firearm attack start logic. It starts a ranged attack action and lets
    the shared attack pump resolve the delayed hit window.
]]

PNC = PNC or {}
PNC.Combat = PNC.Combat or {}

local Combat = PNC.Combat
local Internal = PNC.Combat.Internal or {}
local Core = PNC.Core
local Const = PNC.Const
local Equipment = PNC.Equipment
local Skills = PNC.Skills
local Stamina = PNC.Stamina

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
    if Combat.HasActiveAttack and Combat.HasActiveAttack(record, now) then
        return false, "attack_in_progress"
    end
    if not Internal.canAttack(record, now, cooldownMs) then
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
    Internal.faceTarget(zombie, target)
    if zombie then
        Internal.playAttackSound(zombie, record)
        anim = Internal.triggerRangedWeaponAnim(zombie, record, equipmentInfo)
    end
    Internal.buildAttackAction(record, target, "ranged", "ranged", anim or "PNC_AttackPistol", damage, skillID)
    return true, "ranged_attack_started"
end
