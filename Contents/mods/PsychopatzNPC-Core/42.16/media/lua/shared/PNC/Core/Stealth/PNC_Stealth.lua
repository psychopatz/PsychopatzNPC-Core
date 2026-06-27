PNC = PNC or {}
PNC.Stealth = PNC.Stealth or {}

local Stealth = PNC.Stealth
local Core = PNC.Core
local Const = PNC.Const

local function isManagedNPCBody(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return false
    end
    modData = zombie:getModData()
    return modData and modData.PNC_NPC == true
end

local function getZombieList()
    local cell
    if not getCell then
        return nil
    end
    cell = getCell()
    return cell and cell.getZombieList and cell:getZombieList() or nil
end

local function resolveOwner(record)
    if not record then
        return nil
    end
    return Core.ResolvePlayerByOnlineID(record.ownerOnlineID) or Core.ResolvePlayerByUsername(record.ownerUsername)
end

function Stealth.ResolveOwner(record)
    return resolveOwner(record)
end

function Stealth.Clear(record, reason)
    local runtime
    if not record then
        return false
    end
    runtime = record.runtime or {}
    record.runtime = runtime
    runtime.ownerSneaking = false
    runtime.stealthActive = false
    runtime.stealthBroken = false
    runtime.stealthReason = reason or "inactive"
    return false
end

function Stealth.IsOwnerDiscovered(owner)
    local zombieList
    local i
    local zombie
    local target
    local distSq
    local canSee
    local ok

    if not owner or owner:isDead() then
        return false, "owner_missing"
    end

    zombieList = getZombieList()
    if not zombieList then
        return false, "no_zombies"
    end

    for i = zombieList:size() - 1, 0, -1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) and math.abs(zombie:getZ() - owner:getZ()) < 1 then
            target = zombie.getTarget and zombie:getTarget() or nil
            if target == owner then
                return true, "owner_targeted"
            end

            distSq = Core.DistanceSq(zombie:getX(), zombie:getY(), owner:getX(), owner:getY())
            if distSq <= (Const.STEALTH_BREAK_CONTACT_DISTANCE * Const.STEALTH_BREAK_CONTACT_DISTANCE) then
                return true, "owner_close_contact"
            end

            if distSq <= (Const.STEALTH_DISCOVERY_RADIUS * Const.STEALTH_DISCOVERY_RADIUS) and zombie.CanSee then
                ok, canSee = pcall(zombie.CanSee, zombie, owner)
                if ok and canSee == true then
                    return true, "owner_seen"
                end
            end
        end
    end

    return false, "owner_hidden"
end

function Stealth.UpdateFollowState(record, owner)
    local runtime
    local ownerSneaking
    local discovered
    local reason

    if not record then
        return false
    end

    runtime = record.runtime or {}
    record.runtime = runtime
    owner = owner or resolveOwner(record)
    ownerSneaking = owner and owner.isSneaking and owner:isSneaking() or false

    runtime.ownerSneaking = ownerSneaking
    if (record.orderSpec and record.orderSpec.kind or nil) ~= Const.ORDER_FOLLOW then
        return Stealth.Clear(record, "not_follow_order")
    end
    if not owner or owner:isDead() then
        return Stealth.Clear(record, "owner_missing")
    end
    if not ownerSneaking then
        return Stealth.Clear(record, "owner_not_sneaking")
    end

    discovered, reason = Stealth.IsOwnerDiscovered(owner)
    runtime.stealthBroken = discovered == true
    runtime.stealthActive = discovered ~= true
    runtime.stealthReason = discovered and reason or "follow_stealth"
    return runtime.stealthActive == true
end

function Stealth.IsFollowStealthActive(record)
    local runtime = record and record.runtime or nil
    return runtime and runtime.stealthActive == true and runtime.ownerSneaking == true
end

function Stealth.ShouldSuppressCompanionCombat(record)
    return Stealth.IsFollowStealthActive(record)
end

function Stealth.ShouldSuppressZombieAggro(record)
    return Stealth.IsFollowStealthActive(record)
end

function Stealth.ResolveFollowMoveMode(record, owner, ownerDist)
    if Stealth.IsFollowStealthActive(record) then
        return "sneak"
    end
    if owner and owner.isSprinting and owner:isSprinting() then
        return "run"
    end
    if ownerDist >= Const.FOLLOW_RUN_DISTANCE then
        return "run"
    end
    return "walk"
end
