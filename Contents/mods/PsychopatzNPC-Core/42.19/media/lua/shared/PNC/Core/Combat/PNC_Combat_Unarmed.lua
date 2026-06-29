--[[
    PNC Combat Unarmed
    Owns unarmed shove and ground-finisher animation helpers plus zombie shove
    application used by melee and incapacitated combat flows.
]]

PNC = PNC or {}
PNC.CombatUnarmed = PNC.CombatUnarmed or {}

local Unarmed = PNC.CombatUnarmed
local ZombieReaction = PNC.CombatZombieReaction

local function isGroundTarget(target)
    local methods
    local i
    local method
    local ok
    local result
    local vars
    local actionState

    if not target then
        return false
    end

    methods = { "isOnFloor", "isFallOnFront", "isCrawling", "isKnockedDown", "isProne" }
    for i = 1, #methods do
        method = target[methods[i]]
        if type(method) == "function" then
            ok, result = pcall(method, target)
            if ok and result == true then
                return true
            end
        end
    end

    if target.getVariableBoolean then
        vars = { "bCrawling", "bBecomeCrawler", "FallOnFront", "bKnockedDown" }
        for i = 1, #vars do
            ok, result = pcall(target.getVariableBoolean, target, vars[i])
            if ok and result == true then
                return true
            end
        end
    end

    actionState = target.getActionStateName and string.lower(tostring(target:getActionStateName() or "")) or ""
    return actionState == "onground"
        or actionState == "sitonground"
        or actionState == "climbfence"
        or string.find(actionState, "knockeddown", 1, true) ~= nil
end

function Unarmed.IsGroundTarget(target)
    return isGroundTarget(target)
end

function Unarmed.PlayShove(zombie, record, target)
    local Animation = PNC.Animation
    if not zombie then
        return
    end
    if target and zombie.faceThisObject then
        zombie:faceThisObject(target)
    end
    if Animation and Animation.PlayBump then
        Animation.PlayBump(zombie, record, "PNC_Shove")
    elseif zombie.setBumpType then
        zombie:setBumpType("PNC_Shove")
    end
    if zombie.playSound then
        zombie:playSound("AttackShove")
        zombie:playSound(zombie:isFemale() and "VoiceFemaleMeleeAttack" or "VoiceMaleMeleeAttack")
    end
end

function Unarmed.ApplyZombieShove(attackerZombie, targetZombie, options)
    if not attackerZombie or not targetZombie or targetZombie:isDead() then
        return false
    end
    if ZombieReaction and ZombieReaction.Start then
        return ZombieReaction.Start(attackerZombie, targetZombie, {
            kind = options and options.kind or "shove",
            hitReaction = options and options.hitReaction or "HitReaction",
            hitForce = tonumber(options and options.hitForce) or 1.08,
            pushDistance = tonumber(options and options.pushDistance) or 0.22,
            pushDurationMs = tonumber(options and options.pushDurationMs) or 160,
            durationMs = tonumber(options and options.durationMs) or 240,
            stepDistance = tonumber(options and options.stepDistance) or 0.07,
            stagger = options == nil or options.stagger ~= false,
            heavy = options and options.heavy == true,
            knockdown = options and options.knockdown == true,
        })
    end
    if targetZombie.setAttackedBy then
        targetZombie:setAttackedBy(attackerZombie)
    end
    if targetZombie.setHitForce then
        targetZombie:setHitForce(1.08)
    end
    if targetZombie.setStaggerBack then
        pcall(targetZombie.setStaggerBack, targetZombie, true)
    end
    return true
end

function Unarmed.PlayGroundAttack(zombie, record, target)
    local Animation = PNC.Animation
    local anim = "PNC_Attack2HStamp"
    if not zombie then
        return anim
    end
    if target and (target.isCrawling and target:isCrawling() or target.isProne and target:isProne()) then
        anim = "PNC_Attack2HFloor"
    end
    if Animation and Animation.PlayBump then
        Animation.PlayBump(zombie, record, anim)
    elseif zombie.setBumpType then
        zombie:setBumpType(anim)
    end
    if zombie.playSound then
        if anim == "PNC_Attack2HStamp" then
            zombie:playSound("AttackStomp")
            zombie:playSound(zombie:isFemale() and "VoiceFemaleMeleeStomp" or "VoiceMaleMeleeStomp")
        else
            zombie:playSound(zombie:isFemale() and "VoiceFemaleMeleeAttack" or "VoiceMaleMeleeAttack")
        end
    end
    return anim
end
