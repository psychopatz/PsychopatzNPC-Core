PNC = PNC or {}
PNC.ZombieAggro = PNC.ZombieAggro or {}

local ZombieAggro = PNC.ZombieAggro
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Stealth = PNC.Stealth
local ZombieReaction = PNC.CombatZombieReaction

local Internal = ZombieAggro.Internal

function ZombieAggro.ClearForNPCBody(npcBody)
    local cell
    local zombieList
    local i
    local zombie
    local target
    local forcedRecord
    local forcedBody
    if not npcBody or not getCell then
        return
    end
    ZombieAggro.ClearBiteEntriesForNPCBody(npcBody)
    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return
    end
    for i = zombieList:size() - 1, 0, -1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not Internal.isManagedNPCBody(zombie)) then
            target = zombie.getTarget and zombie:getTarget() or nil
            forcedRecord, forcedBody = Internal.getForcedNPCBodyTarget(zombie)
            if target == npcBody or forcedBody == npcBody then
                Internal.clearZombieTarget(zombie)
                ZombieAggro.ClearBiteEntryForZombie(zombie)
            end
        end
    end
end

function ZombieAggro.OnZombieProvoked(zombie, npcBody)
    if not zombie or not npcBody or zombie:isDead() or Internal.isManagedNPCBody(zombie) then
        return
    end
    Internal.forceAggro(zombie, npcBody)
end

function ZombieAggro.Pump(now)
    local cell
    local zombieList
    local i
    local zombie
    local target
    local record
    local npcBody
    local distSq
    local dist
    local nearestRecord
    local nearestBody
    local nearestDistSq

    if not Core.IsAuthority() or not getCell then
        return
    end

    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return
    end

    for i = zombieList:size() - 1, 0, -1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not Internal.isManagedNPCBody(zombie)) then
            if ZombieReaction and ZombieReaction.Pump and ZombieReaction.Pump(zombie, now) then
                -- Combat reaction windows temporarily own the zombie body.
            elseif ZombieAggro.UpdateBiteState(zombie, now) then
                -- Bite flow owns the zombie while the bite is active.
            else
                target = zombie.getTarget and zombie:getTarget() or nil

                if Internal.isCloseLivePlayerTarget(zombie, target) then
                    if zombie.setVariable then
                        zombie:setVariable("NoLungeAttack", false)
                    end
                else
                    if target and target.getModData and target:getModData().PNC_NPC == true then
                        Internal.forceAggro(zombie, target)
                    end

                    record, npcBody = Internal.getForcedNPCBodyTarget(zombie)
                    if record and npcBody then
                        if Stealth and Stealth.ShouldSuppressZombieAggro and Stealth.ShouldSuppressZombieAggro(record) then
                            Internal.clearZombieTarget(zombie)
                            ZombieAggro.ClearBiteEntryForZombie(zombie)
                            if zombie.setVariable then
                                zombie:setVariable("NoLungeAttack", false)
                            end
                            record.runtime = record.runtime or {}
                            record.runtime.combatBlockReason = "follow_stealth_hidden"
                        else
                            distSq = Core.DistanceSq(zombie:getX(), zombie:getY(), npcBody:getX(), npcBody:getY())
                            dist = math.sqrt(distSq)
                            if zombie.setVariable then
                                zombie:setVariable("NoLungeAttack", dist <= Const.ZOMBIE_AGGRO_KEEP_RADIUS)
                            end
                            if dist < Const.ZOMBIE_BITE_DISTANCE and math.abs(zombie:getZ() - npcBody:getZ()) < 0.3 then
                                if zombie.getSquare and npcBody.getSquare and zombie:getSquare() and npcBody:getSquare()
                                    and not zombie:getSquare():isSomethingTo(npcBody:getSquare())
                                then
                                    if zombie.isFacingObject and zombie:isFacingObject(npcBody, 0.3) then
                                        ZombieAggro.TryStartBite(zombie, npcBody, record)
                                    elseif zombie.faceThisObject then
                                        zombie:faceThisObject(npcBody)
                                    end
                                end
                            elseif npcBody and zombie.pathToCharacter then
                                zombie:pathToCharacter(npcBody)
                            elseif npcBody and zombie.pathToLocation then
                                zombie:pathToLocation(npcBody:getX(), npcBody:getY(), npcBody:getZ())
                            end
                        end
                    else
                        nearestRecord, nearestBody, nearestDistSq = Internal.findNearestLiveNPC(zombie, Const.ZOMBIE_AGGRO_RADIUS)
                        if nearestRecord and nearestBody then
                            Internal.forceAggro(zombie, nearestBody)
                            if zombie.setVariable then
                                zombie:setVariable("NoLungeAttack", math.sqrt(nearestDistSq) <= Const.ZOMBIE_AGGRO_KEEP_RADIUS)
                            end
                        elseif zombie.setVariable then
                            zombie:setVariable("NoLungeAttack", false)
                        end
                    end
                end
            end
        end
    end
end
