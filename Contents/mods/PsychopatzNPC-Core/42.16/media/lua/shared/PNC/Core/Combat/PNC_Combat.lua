--[[
    PNC Combat Entry
    Owns shared combat helpers, PNC-specific animation identifiers, and the
    public combat table used by melee, ranged, and tactics submodules.
]]

PNC = PNC or {}
PNC.Combat = PNC.Combat or {}

PNC.Combat.Internal = PNC.Combat.Internal or {}

local Combat = PNC.Combat
local Internal = Combat.Internal
local Core = PNC.Core
local Registry = PNC.Registry
local Animation = PNC.Animation
local Equipment = PNC.Equipment
local Perception = PNC.Perception

Internal.MELEE_BUMP_TYPES = {
    onehanded = { "PNC_Attack1H1" },
    twohanded = { "PNC_Attack2H1" },
    spear = { "PNC_AttackS1" },
    knife = { "PNC_AttackKnife" },
}

Internal.RANGED_BUMP_TYPES = {
    handgun = { "PNC_AttackPistol" },
    rifle = { "PNC_AttackRifle" },
}

Internal.ATTACK_TIMINGS = {
    melee = { hitDelay = 260, duration = 720 },
    ranged = { hitDelay = 180, duration = 620 },
    shove = { hitDelay = 130, duration = 480 },
    ground = { hitDelay = 240, duration = 760 },
}

function Internal.faceTarget(zombie, target)
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
        if liveTarget and zombie.faceThisObject then
            zombie:faceThisObject(liveTarget)
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

function Internal.canAttack(record, now, cooldownMs)
    cooldownMs = cooldownMs or 1000
    return (now - (tonumber(record.runtime.lastAttackAt) or 0)) >= cooldownMs
end

function Internal.resolveWeaponItem(record)
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

function Internal.resolveMeleeAnimFamily(record, equipmentInfo)
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

function Internal.triggerMeleeWeaponAnim(zombie, record, equipmentInfo)
    local options = Internal.MELEE_BUMP_TYPES[Internal.resolveMeleeAnimFamily(record, equipmentInfo)] or Internal.MELEE_BUMP_TYPES.onehanded
    local anim
    if not zombie or not Animation or not Animation.PlayBump or not options or #options <= 0 then
        return nil
    end
    anim = options[ZombRand(#options) + 1]
    Animation.PlayBump(zombie, record, anim)
    return anim
end

function Internal.triggerRangedWeaponAnim(zombie, record, equipmentInfo)
    local family = equipmentInfo and equipmentInfo.primaryType == "rifle" and "rifle" or "handgun"
    local options = Internal.RANGED_BUMP_TYPES[family] or Internal.RANGED_BUMP_TYPES.handgun
    local anim
    if not zombie or not Animation or not Animation.PlayBump or not options or #options <= 0 then
        return nil
    end
    anim = options[ZombRand(#options) + 1]
    Animation.PlayBump(zombie, record, anim)
    return anim
end

function Internal.playAttackSound(zombie, record)
    local item
    local emitter
    local swingSound
    if not zombie or not zombie.getEmitter then
        return
    end
    item = Internal.resolveWeaponItem(record)
    emitter = zombie:getEmitter()
    swingSound = item and item.getSwingSound and item:getSwingSound() or nil
    if swingSound and swingSound ~= "" and emitter and emitter.playSound then
        emitter:playSound(swingSound)
    end
end
