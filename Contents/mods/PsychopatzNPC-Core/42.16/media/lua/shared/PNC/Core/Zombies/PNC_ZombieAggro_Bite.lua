PNC = PNC or {}
PNC.ZombieAggro = PNC.ZombieAggro or {}

local ZombieAggro = PNC.ZombieAggro
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Health = PNC.Health
local Equipment = PNC.Equipment

local State = ZombieAggro.State
local Internal = ZombieAggro.Internal

local function getBiteEntry(zombieId)
    return zombieId and State.bites and State.bites[zombieId] or nil
end

local function clearBiteEntry(zombieId, npcBody)
    local entry
    if not zombieId or not State.bites then
        return
    end
    entry = State.bites[zombieId]
    if entry and entry.npcBody and entry.npcBody.setZombiesDontAttack then
        entry.npcBody:setZombiesDontAttack(false)
    elseif npcBody and npcBody.setZombiesDontAttack then
        npcBody:setZombiesDontAttack(false)
    end
    State.bites[zombieId] = nil
end

function ZombieAggro.ClearBiteEntryForZombie(zombie)
    local zombieId = Internal.ensureZombieID(zombie)
    clearBiteEntry(zombieId, nil)
end

function ZombieAggro.ClearBiteEntriesForNPCBody(npcBody)
    local zombieId
    local entry
    if not npcBody or not State.bites then
        return
    end
    for zombieId, entry in pairs(State.bites) do
        if entry and entry.npcBody == npcBody then
            clearBiteEntry(zombieId, npcBody)
        end
    end
end

function ZombieAggro.TryStartBite(zombie, npcBody, record)
    local zombieId
    local asn
    local bumpType

    if not zombie or not npcBody or not record then
        return false
    end

    zombieId = Internal.ensureZombieID(zombie)
    if not zombieId then
        return false
    end
    if getBiteEntry(zombieId) then
        return true
    end

    asn = zombie.getActionStateName and zombie:getActionStateName() or ""
    bumpType = zombie.getBumpType and zombie:getBumpType() or ""
    if asn == "staggerback" or bumpType == "Bite" or bumpType == "BiteLow" then
        return false
    end

    if npcBody.setZombiesDontAttack then
        npcBody:setZombiesDontAttack(true)
    end
    if zombie.setBumpType then
        if npcBody.isProne and npcBody:isProne() or npcBody.isCrawling and npcBody:isCrawling() then
            zombie:setBumpType("BiteLow")
        else
            zombie:setBumpType("Bite")
        end
    end

    State.bites[zombieId] = {
        npcId = record.id,
        npcBody = npcBody,
        tick = 0,
    }
    Core.LogRecordDebug(record, "Zombie " .. tostring(zombieId) .. " started bite on NPC " .. tostring(record.id))
    return true
end

function ZombieAggro.UpdateBiteState(zombie, now)
    local zombieId
    local entry
    local record
    local npcBody
    local asn
    local bumpType
    local tick
    local dist
    local teeth

    if not zombie or zombie:isDead() then
        return false
    end

    zombieId = Internal.ensureZombieID(zombie)
    entry = getBiteEntry(zombieId)
    if not entry then
        return false
    end

    record = Registry.Get(entry.npcId)
    npcBody = entry.npcBody
    if not record or not npcBody or record.alive == false or record.presenceState ~= Const.PRESENCE_LIVE or npcBody:isDead() then
        clearBiteEntry(zombieId, npcBody)
        return true
    end

    asn = zombie.getActionStateName and zombie:getActionStateName() or ""
    bumpType = zombie.getBumpType and zombie:getBumpType() or ""
    if (bumpType == "Bite" or bumpType == "BiteLow") and asn == "bumped" then
        tick = tonumber(entry.tick or 0) or 0
        if tick == Const.ZOMBIE_BITE_APPLY_TICK then
            dist = Core.Distance(zombie:getX(), zombie:getY(), npcBody:getX(), npcBody:getY())
            if dist < Const.ZOMBIE_BITE_DISTANCE then
                if ZombRand(4) == 1 and zombie.playSound then
                    zombie:playSound("ZombieBite")
                elseif zombie.playSound then
                    zombie:playSound("ZombieScratch")
                end
                if Equipment and Equipment.CreateItem then
                    teeth = Equipment.CreateItem("Base.RollingPin")
                end
                if npcBody.setHitFromBehind and zombie.isBehind then
                    npcBody:setHitFromBehind(zombie:isBehind(npcBody))
                end
                if npcBody.setPlayerAttackPosition and npcBody.testDotSide then
                    npcBody:setPlayerAttackPosition(npcBody:testDotSide(zombie))
                end
                record.runtime.target = {
                    kind = "zombie",
                    zombieId = zombieId,
                    x = zombie:getX(),
                    y = zombie:getY(),
                    z = zombie:getZ(),
                    distSq = Core.DistanceSq(zombie:getX(), zombie:getY(), npcBody:getX(), npcBody:getY()),
                }
                record.runtime.targetKind = "zombie"
                record.runtime.combatBlockReason = "under_zombie_bite"
                if teeth and npcBody.Hit then
                    pcall(function()
                        npcBody:Hit(teeth, zombie, 1.01, false, 1, false)
                    end)
                end
                Health.ApplyDamage(record, npcBody, {
                    amount = Const.ZOMBIE_ATTACK_DAMAGE,
                    type = "zombie_bite",
                    attackerKind = "zombie",
                })
                Core.LogRecordDebug(record, "Zombie " .. tostring(zombieId) .. " applied bite to NPC " .. tostring(record.id))
            end
        elseif tick >= Const.ZOMBIE_BITE_CLEAR_TICK then
            clearBiteEntry(zombieId, npcBody)
            return true
        end
        entry.tick = tick + 1
        return true
    end

    if bumpType ~= "Bite" and bumpType ~= "BiteLow" then
        clearBiteEntry(zombieId, npcBody)
    end
    return true
end
