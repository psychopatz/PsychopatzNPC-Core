PNC = PNC or {}
PNC.ZombieAggro = PNC.ZombieAggro or {}

local ZombieAggro = PNC.ZombieAggro
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Health = PNC.Health

local function ensureZombieID(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return nil
    end
    modData = zombie:getModData()
    if not modData then
        return nil
    end
    if not modData.PNC_ZombieID or tostring(modData.PNC_ZombieID) == "" then
        modData.PNC_ZombieID = Core.GenerateID("pz")
    end
    return modData.PNC_ZombieID
end

local function getZombieModData(zombie)
    return zombie and zombie.getModData and zombie:getModData() or nil
end

local function isManagedNPCBody(zombie)
    local modData = getZombieModData(zombie)
    return modData and modData.PNC_NPC == true
end

local function clearZombieTarget(zombie)
    if not zombie then
        return
    end
    if zombie.clearAggroList then
        zombie:clearAggroList()
    end
    if zombie.setTarget then
        zombie:setTarget(nil)
    end
    if zombie.setAttackedBy then
        zombie:setAttackedBy(nil)
    end
    if zombie.setVariable then
        zombie:setVariable("NoLungeAttack", false)
    end
end

local function isCloseLivePlayerTarget(zombie, target)
    local dx
    local dy
    if not zombie or not target or not instanceof or not instanceof(target, "IsoPlayer") then
        return false
    end
    dx = target:getX() - zombie:getX()
    dy = target:getY() - zombie:getY()
    return ((dx * dx) + (dy * dy)) <= (Const.ZOMBIE_TARGET_PLAYER_KEEP_RADIUS * Const.ZOMBIE_TARGET_PLAYER_KEEP_RADIUS)
end

local function findNearestLiveNPC(zombie, radius)
    local bestRecord
    local bestBody
    local bestDistSq
    local zx
    local zy
    local zz
    local limitSq

    if not zombie then
        return nil, nil, math.huge
    end

    zx = zombie:getX()
    zy = zombie:getY()
    zz = zombie:getZ()
    limitSq = radius * radius
    bestDistSq = math.huge

    Registry.ForEachLive(function(record, npcBody)
        local distSq
        if npcBody
            and record
            and record.alive ~= false
            and record.presenceState == Const.PRESENCE_LIVE
            and math.abs(npcBody:getZ() - zz) < 1
        then
            distSq = Core.DistanceSq(zx, zy, npcBody:getX(), npcBody:getY())
            if distSq <= limitSq and distSq < bestDistSq then
                bestRecord = record
                bestBody = npcBody
                bestDistSq = distSq
            end
        end
    end)

    return bestRecord, bestBody, bestDistSq
end

local function canZombieAttack(zombie, now)
    local modData = getZombieModData(zombie)
    local lastAttackAt
    if not modData then
        return false
    end
    lastAttackAt = tonumber(modData.PNC_LastAttackAt or 0) or 0
    if (now - lastAttackAt) < Const.ZOMBIE_ATTACK_COOLDOWN_MS then
        return false
    end
    modData.PNC_LastAttackAt = now
    return true
end

local function forceAggro(zombie, npcBody)
    if zombie.spotted then
        zombie:spotted(npcBody, true)
    end
    if zombie.addAggro then
        zombie:addAggro(npcBody, 1)
    end
    if zombie.setTarget then
        zombie:setTarget(npcBody)
    end
    if zombie.setAttackedBy then
        zombie:setAttackedBy(npcBody)
    end
end

function ZombieAggro.ClearForNPCBody(npcBody)
    local cell
    local zombieList
    local i
    local zombie
    local target
    if not npcBody or not getCell then
        return
    end
    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return
    end
    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) then
            target = zombie.getTarget and zombie:getTarget() or nil
            if target == npcBody then
                clearZombieTarget(zombie)
            end
        end
    end
end

function ZombieAggro.OnZombieProvoked(zombie, npcBody)
    if not zombie or not npcBody or zombie:isDead() or isManagedNPCBody(zombie) then
        return
    end
    forceAggro(zombie, npcBody)
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
    local zombieId
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

    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) then
            target = zombie.getTarget and zombie:getTarget() or nil

            if isCloseLivePlayerTarget(zombie, target) then
                if zombie.setVariable then
                    zombie:setVariable("NoLungeAttack", false)
                end
            else
                if target and target.getModData and target:getModData().PNC_NPC == true then
                    npcBody = target
                    record = Registry.FindRecordByZombie(npcBody)
                    if record and record.alive ~= false and record.presenceState == Const.PRESENCE_LIVE then
                        distSq = Core.DistanceSq(zombie:getX(), zombie:getY(), npcBody:getX(), npcBody:getY())
                        dist = math.sqrt(distSq)
                        if zombie.setVariable then
                            zombie:setVariable("NoLungeAttack", dist <= Const.ZOMBIE_AGGRO_KEEP_RADIUS)
                        end
                        if dist <= Const.ZOMBIE_ATTACK_RANGE and canZombieAttack(zombie, now) then
                            zombieId = ensureZombieID(zombie)
                            record.runtime.target = {
                                kind = "zombie",
                                zombieId = zombieId,
                                x = zombie:getX(),
                                y = zombie:getY(),
                                z = zombie:getZ(),
                                distSq = distSq,
                            }
                            record.runtime.targetKind = "zombie"
                            record.runtime.combatBlockReason = "under_zombie_attack"
                            Health.ApplyDamage(record, npcBody, {
                                amount = Const.ZOMBIE_ATTACK_DAMAGE,
                                type = "zombie_bite",
                                attackerKind = "zombie",
                            })
                            Core.LogRecordDebug(record, "NPC " .. tostring(record.id) .. " took zombie damage from " .. tostring(zombieId))
                        elseif npcBody and zombie.pathToCharacter then
                            zombie:pathToCharacter(npcBody)
                        elseif npcBody and zombie.pathToLocation then
                            zombie:pathToLocation(npcBody:getX(), npcBody:getY(), npcBody:getZ())
                        end
                    else
                        clearZombieTarget(zombie)
                    end
                else
                    nearestRecord, nearestBody, nearestDistSq = findNearestLiveNPC(zombie, Const.ZOMBIE_AGGRO_RADIUS)
                    if nearestRecord and nearestBody then
                        forceAggro(zombie, nearestBody)
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
