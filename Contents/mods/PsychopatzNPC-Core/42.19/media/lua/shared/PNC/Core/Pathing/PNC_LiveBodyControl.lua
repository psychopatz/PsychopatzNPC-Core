--[[
    PNC Live Body Control
    Owns suppression of vanilla zombie-only body states on embodied NPCs.
    This stays separate from path ownership so animation, presence, and pathing
    can reuse the same body-state rules without duplicating them.
]]

PNC = PNC or {}
PNC.LiveBodyControl = PNC.LiveBodyControl or {}

local LiveBodyControl = PNC.LiveBodyControl
local Core = PNC.Core

local SUPPRESSION_AUDIO_COOLDOWN_MS = 1000
local SUPPRESSED_STATES = {
    ["getup"] = true,
    ["getup-fromonback"] = true,
    ["getup-fromonfront"] = true,
    ["getup-fromsitting"] = true,
    ["lunge"] = true,
    ["onground"] = true,
    ["onground-ragdoll"] = true,
    ["sitonground"] = true,
    ["staggerback"] = true,
    ["staggerback-knockeddown"] = true,
}

function LiveBodyControl.IsSuppressedActionState(actionState)
    if not actionState or actionState == "" then
        return false
    end
    return SUPPRESSED_STATES[string.lower(tostring(actionState))] == true
end

function LiveBodyControl.GetActionStateName(zombie)
    if not zombie or not zombie.getActionStateName then
        return ""
    end
    return string.lower(tostring(zombie:getActionStateName() or ""))
end

function LiveBodyControl.ApplyHumanizedBodyFlags(zombie)
    if not zombie then
        return
    end
    if zombie.setVariable then
        zombie:setVariable("ZombieHitReaction", "Chainsaw")
        zombie:setVariable("NoLungeTarget", true)
        zombie:setVariable("NoLungeAttack", true)
        zombie:setVariable("bBecomeCrawler", false)
        zombie:setVariable("bCrawling", false)
        zombie:setVariable("FallOnFront", false)
        zombie:setVariable("PNCLive", true)
    end
    if zombie.setKnockedDown then
        zombie:setKnockedDown(false)
    end
    if zombie.setSitAgainstWall then
        zombie:setSitAgainstWall(false)
    end
    if zombie.setOnFloor then
        zombie:setOnFloor(false)
    end
    if zombie.setFallOnFront then
        zombie:setFallOnFront(false)
    end
    if zombie.setCrawler then
        zombie:setCrawler(false)
    end
    if zombie.setFakeDead then
        zombie:setFakeDead(false)
    end
    if zombie.setCanWalk then
        zombie:setCanWalk(true)
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.setAttackedBy then
        zombie:setAttackedBy(nil)
    end
    if zombie.setTurnAlertedValues then
        zombie:setTurnAlertedValues(-5, 5)
    end
end

function LiveBodyControl.StopEmitter(zombie)
    local emitter
    if not zombie or not zombie.getEmitter then
        return false
    end
    emitter = zombie:getEmitter()
    if not emitter or not emitter.stopAll then
        return false
    end
    emitter:stopAll()
    return true
end

function LiveBodyControl.TrySilenceEmitter(zombie, lane, now)
    if not lane then
        return false
    end
    now = tonumber(now) or (Core and Core.Now and Core.Now() or 0)
    if (now - (tonumber(lane.lastSuppressAudioAt) or 0)) < SUPPRESSION_AUDIO_COOLDOWN_MS then
        return false
    end
    if not LiveBodyControl.StopEmitter(zombie) then
        return false
    end
    lane.lastSuppressAudioAt = now
    return true
end

function LiveBodyControl.SuppressZombieState(zombie, lane, now)
    local actionState = LiveBodyControl.GetActionStateName(zombie)
    if not zombie then
        return false, actionState
    end
    LiveBodyControl.ApplyHumanizedBodyFlags(zombie)
    LiveBodyControl.TrySilenceEmitter(zombie, lane, now)
    if not LiveBodyControl.IsSuppressedActionState(actionState) then
        return false, actionState
    end
    if zombie.setUseless then
        zombie:setUseless(true)
    end
    if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        zombie:changeState(ZombieIdleState.instance())
    end
    LiveBodyControl.TrySilenceEmitter(zombie, lane, now)
    return true, actionState
end
