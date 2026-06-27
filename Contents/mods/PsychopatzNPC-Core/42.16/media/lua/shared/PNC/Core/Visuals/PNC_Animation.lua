PNC = PNC or {}
PNC.Animation = PNC.Animation or {}

local Animation = PNC.Animation

function Animation.ApplyLiveSetup(zombie, record)
    if not zombie or not record then
        return
    end
    if zombie.setNoTeeth then
        zombie:setNoTeeth(true)
    end
    if zombie.setFemaleEtc then
        zombie:setFemaleEtc(record.isFemale == true)
    end
    if zombie.setVariable then
        zombie:setVariable("Bandit", true)
        zombie:setVariable("BanditWalkType", "Walk")
        zombie:setVariable("BanditPrimary", "")
        zombie:setVariable("BanditSecondary", "")
        zombie:setVariable("BanditPrimaryType", "barehand")
        zombie:setVariable("LimpSpeed", 0.80)
        zombie:setVariable("RunSpeed", 0.72)
        zombie:setVariable("WalkSpeed", 1.04)
        zombie:setVariable("ZombieHitReaction", "Chainsaw")
        zombie:setVariable("NoLungeTarget", true)
        zombie:setVariable("PNCLive", true)
    end
    if zombie.setWalkType then
        zombie:setWalkType("Walk")
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
    if zombie.setPrimaryHandItem then
        zombie:setPrimaryHandItem(nil)
    end
    if zombie.setSecondaryHandItem then
        zombie:setSecondaryHandItem(nil)
    end
    if zombie.resetEquippedHandsModels then
        zombie:resetEquippedHandsModels()
    end
    if zombie.clearAttachedItems then
        zombie:clearAttachedItems()
    end
    if zombie.setTurnAlertedValues then
        zombie:setTurnAlertedValues(-5, 5)
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
    if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        zombie:changeState(ZombieIdleState.instance())
    end
    if zombie.getEmitter then
        zombie:getEmitter():stopAll()
    end
    if zombie.getDescriptor then
        local descriptor = zombie:getDescriptor()
        if descriptor and descriptor.setVoicePrefix then
            descriptor:setVoicePrefix("Bandit")
        end
    end
end

function Animation.Apply(zombie, record, animState)
    local previousWalkType
    if not zombie or not record then
        return
    end
    previousWalkType = zombie.getVariableString and zombie:getVariableString("BanditWalkType") or ""
    zombie:setVariable("PNC", true)
    zombie:setVariable("PNCState", tostring(record.activeBehavior or record.activeJob or "Idle"))
    zombie:setVariable("PNCOrder", tostring(record.orderSpec and record.orderSpec.kind or "none"))
    zombie:setVariable("PNCPresence", tostring(record.presenceState or "unknown"))
    zombie:setVariable("PNCAnim", tostring(animState or "Idle"))
    zombie:setVariable("PNCWeaponMode", tostring(record.weaponMode or "melee"))
    if animState == "Run" or animState == "Walk" then
        zombie:setVariable("BanditWalkType", animState)
        if zombie.setWalkType then
            zombie:setWalkType(animState)
        end
    elseif animState == "Idle" then
        if previousWalkType == "Run" and zombie.setBumpType then
            zombie:setBumpType("RunToIdle")
        elseif previousWalkType == "Walk" and zombie.setBumpType then
            zombie:setBumpType("WalkToIdle")
        end
        zombie:setVariable("BanditWalkType", "")
        if zombie.setWalkType then
            zombie:setWalkType("Walk")
        end
        if zombie.setTarget then
            zombie:setTarget(nil)
        end
    end
end
