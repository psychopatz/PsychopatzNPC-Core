PNC = PNC or {}
PNC.Network = PNC.Network or {}
PNC.Network.ClientState = PNC.Network.ClientState or { snapshots = {} }

local Network = PNC.Network
local Core = PNC.Core
local Const = PNC.Const

function Network.BuildSnapshot(record)
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
        weaponMode = record.weaponMode,
        weaponFullType = record.equipment and record.equipment.primaryFullType or nil,
        presenceRevision = record.presenceRevision,
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
