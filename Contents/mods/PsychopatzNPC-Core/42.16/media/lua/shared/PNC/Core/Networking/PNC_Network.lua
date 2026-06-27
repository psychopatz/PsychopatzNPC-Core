PNC = PNC or {}
PNC.Network = PNC.Network or {}
PNC.Network.ClientState = PNC.Network.ClientState or { snapshots = {} }

local Network = PNC.Network
local Core = PNC.Core
local Const = PNC.Const
local Equipment = PNC.Equipment

local function resolveAIState(record)
    local healthState = record.health and tostring(record.health.state or "normal") or "normal"
    local hasTarget = record.runtime and record.runtime.target ~= nil
    local inCombat = hasTarget
        or ((tonumber(record.runtime and record.runtime.inCombatUntil or 0) or 0) > Core.Now())

    if record.alive == false then
        return "Dead", false
    end
    if healthState == "incapacitated" then
        return "Incapacitated", false
    end
    if record.presenceState == Const.PRESENCE_ABSTRACT then
        return "Abstract", false
    end
    if inCombat then
        return "Combat", true
    end
    if record.activeBehavior and record.activeBehavior ~= "" then
        return tostring(record.activeBehavior), false
    end
    return "Idle", false
end

function Network.BuildSnapshot(record)
    local aiState
    local inCombat
    local target = record.runtime and record.runtime.target or nil
    local equipmentInfo = Equipment and Equipment.Describe and Equipment.Describe(record) or {}
    aiState, inCombat = resolveAIState(record)
    return {
        id = record.id,
        name = record.name,
        faction = record.faction,
        visualProfile = record.visualProfile,
        isFemale = record.isFemale,
        x = record.x,
        y = record.y,
        z = record.z,
        orderKind = record.orderSpec and record.orderSpec.kind or nil,
        activeJob = record.activeJob,
        activeBehavior = record.activeBehavior,
        presenceState = record.presenceState,
        alive = record.alive,
        hpCurrent = record.health and record.health.current or nil,
        hpMax = record.health and record.health.max or nil,
        healthState = record.health and record.health.state or nil,
        recentDamageUntil = record.health and record.health.recentDamageUntil or 0,
        weaponMode = record.weaponMode,
        weaponFullType = record.equipment and record.equipment.primaryFullType or nil,
        combatModeResolved = equipmentInfo.combatModeResolved or record.weaponMode,
        weaponStatus = equipmentInfo.weaponStatus or "unknown",
        presenceRevision = record.presenceRevision,
        aiState = aiState,
        inCombat = inCombat,
        debugState = {
            aiState = aiState,
            activeJob = record.activeJob,
            activeBehavior = record.activeBehavior,
            orderKind = record.orderSpec and record.orderSpec.kind or nil,
            targetKind = target and target.kind or nil,
            healthState = record.health and record.health.state or nil,
            weaponMode = record.weaponMode,
            combatModeResolved = equipmentInfo.combatModeResolved or record.weaponMode,
            weaponStatus = equipmentInfo.weaponStatus or "unknown",
            combatBlockReason = record.runtime and record.runtime.combatBlockReason or nil,
            debugEnabled = record.runtime and record.runtime.debug == true or false,
            presenceState = record.presenceState,
        },
    }
end

function Network.BroadcastRecord(record, eventName)
    local payload
    if not Core.IsAuthority() then
        return
    end
    payload = {
        event = eventName or "update",
        snapshot = Network.BuildSnapshot(record),
    }
    if isServer and isServer() then
        sendServerCommand(Const.MODULE, Const.CMD_SYNC_RECORD, payload)
    else
        triggerEvent("OnServerCommand", Const.MODULE, Const.CMD_SYNC_RECORD, payload)
    end
end

function Network.BroadcastRemoval(id, reason)
    local payload = { id = id, reason = reason }
    if not Core.IsAuthority() then
        return
    end
    if isServer and isServer() then
        sendServerCommand(Const.MODULE, Const.CMD_REMOVE_RECORD, payload)
    else
        triggerEvent("OnServerCommand", Const.MODULE, Const.CMD_REMOVE_RECORD, payload)
    end
end

function Network.BroadcastFullSync(targetPlayer, records)
    local payload = { snapshots = records }
    if isServer and isServer() and targetPlayer then
        sendServerCommand(targetPlayer, Const.MODULE, Const.CMD_FULL_SYNC, payload)
    elseif not isServer or not isServer() then
        triggerEvent("OnServerCommand", Const.MODULE, Const.CMD_FULL_SYNC, payload)
    end
end
