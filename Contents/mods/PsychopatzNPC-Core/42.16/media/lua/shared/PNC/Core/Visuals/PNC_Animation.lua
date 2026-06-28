PNC = PNC or {}
PNC.Animation = PNC.Animation or {}

local Animation = PNC.Animation

local function setPNCStateVars(zombie, record, animState)
    if not zombie or not zombie.setVariable then
        return
    end
    zombie:setVariable("PNC", true)
    zombie:setVariable("PNCState", tostring(record and (record.activeBehavior or record.activeJob) or "Idle"))
    zombie:setVariable("PNCOrder", tostring(record and record.orderSpec and record.orderSpec.kind or "none"))
    zombie:setVariable("PNCPresence", tostring(record and record.presenceState or "unknown"))
    zombie:setVariable("PNCAnim", tostring(animState or "Idle"))
    zombie:setVariable("PNCWeaponMode", tostring(record and record.weaponMode or "melee"))
end

local function setLocomotionVars(zombie, walkType, moving)
    if not zombie then
        return
    end
    if zombie.setVariable then
        zombie:setVariable("PNCWalkType", tostring(walkType or ""))
        zombie:setVariable("PNCMoving", moving == true)
        zombie:setVariable("bMoving", moving == true)
        zombie:setVariable("isMoving", moving == true)
    end
end

local function applyWalkType(zombie, walkType)
    if not zombie then
        return
    end
    if zombie.setWalkType then
        zombie:setWalkType(tostring(walkType or ""))
    end
    if zombie.setSpeedMod then
        zombie:setSpeedMod(1)
    end
    if zombie.setAnimatingBackwards then
        zombie:setAnimatingBackwards(false)
    end
end

function Animation.ApplyLiveSetup(zombie, record)
    local descriptor
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
        zombie:setVariable("LimpSpeed", 0.80)
        zombie:setVariable("RunSpeed", 0.72)
        zombie:setVariable("WalkSpeed", 1.04)
        zombie:setVariable("ZombieHitReaction", "Chainsaw")
        zombie:setVariable("NoLungeTarget", false)
        zombie:setVariable("PNCActor", true)
        zombie:setVariable("PNCWalkType", "")
        zombie:setVariable("PNCPrimary", "")
        zombie:setVariable("PNCSecondary", "")
        zombie:setVariable("PNCPrimaryType", "barehand")
        zombie:setVariable("PNCImmediateAnim", false)
        zombie:setVariable("PNCLive", true)
        zombie:setVariable("PNCMoving", false)
        zombie:setVariable("bMoving", false)
        zombie:setVariable("isMoving", false)
    end
    applyWalkType(zombie, "")
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
        descriptor = zombie:getDescriptor()
        if descriptor and descriptor.setVoicePrefix then
            descriptor:setVoicePrefix("NotAZombie")
        end
    end
end

function Animation.Apply(zombie, record, animState)
    local walkType = ""
    local moving = false
    if not zombie or not record then
        return
    end
    setPNCStateVars(zombie, record, animState)
    if animState == "Run" or animState == "Walk" or animState == "SneakWalk" then
        walkType = animState
        moving = true
    elseif animState == "Crawl" then
        walkType = "Walk"
        moving = true
    end
    setLocomotionVars(zombie, walkType, moving)
end

function Animation.ApplyDowned(zombie, record, moving)
    if not zombie then
        return
    end
    zombie:setVariable("PNC", true)
    zombie:setVariable("PNCState", tostring(record and (record.activeBehavior or record.activeJob) or "Incapacitated"))
    zombie:setVariable("PNCAnim", moving and "Crawl" or "Downed")
    zombie:setVariable("PNCWalkType", moving and "Walk" or "")
    zombie:setVariable("bBecomeCrawler", true)
    zombie:setVariable("bCrawling", true)
    zombie:setVariable("FallOnFront", true)
    zombie:setVariable("bMoving", moving == true)
    zombie:setVariable("isMoving", moving == true)
    if zombie.setCrawler then
        zombie:setCrawler(true)
    end
    if zombie.setOnFloor then
        zombie:setOnFloor(true)
    end
    if zombie.setFallOnFront then
        zombie:setFallOnFront(true)
    end
    if zombie.setCanWalk then
        zombie:setCanWalk(true)
    end
    if zombie.setRunning then
        zombie:setRunning(false)
    end
    if zombie.setUseless then
        zombie:setUseless(false)
    end
    applyWalkType(zombie, moving and "Walk" or "")
end

function Animation.ClearDowned(zombie)
    if not zombie then
        return
    end
    zombie:setVariable("bBecomeCrawler", false)
    zombie:setVariable("bCrawling", false)
    zombie:setVariable("FallOnFront", false)
    zombie:setVariable("bMoving", false)
    zombie:setVariable("isMoving", false)
    if zombie.setCrawler then
        zombie:setCrawler(false)
    end
    if zombie.setOnFloor then
        zombie:setOnFloor(false)
    end
    if zombie.setFallOnFront then
        zombie:setFallOnFront(false)
    end
    setLocomotionVars(zombie, "", false)
    applyWalkType(zombie, "")
end

function Animation.PlayBump(zombie, record, bumpType)
    if not zombie then
        return
    end
    setPNCStateVars(zombie, record, bumpType or "Bump")
    setLocomotionVars(zombie, "", false)
    applyWalkType(zombie, "")
    if zombie.setRunning then
        zombie:setRunning(false)
    end
    if zombie.setBumpDone then
        pcall(zombie.setBumpDone, zombie, false)
    end
    if zombie.setVariable then
        zombie:setVariable("BumpAnimFinished", false)
    end
    if zombie.setBumpType then
        zombie:setBumpType(tostring(bumpType or "Bump"))
    end
end

function Animation.SyncLocomotion(zombie)
    local walkType
    if not zombie then
        return
    end
    walkType = zombie.getVariableString and zombie:getVariableString("PNCWalkType") or ""
    applyWalkType(zombie, walkType)
    if zombie.setUseless then
        zombie:setUseless(false)
    end
end
