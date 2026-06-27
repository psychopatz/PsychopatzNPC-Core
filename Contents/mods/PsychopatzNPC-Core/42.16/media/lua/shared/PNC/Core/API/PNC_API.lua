PNC = PNC or {}
PNC.API = PNC.API or {}

local API = PNC.API
local Core = PNC.Core
local Types = PNC.Types
local Registry = PNC.Registry
local OrderSystem = PNC.OrderSystem
local Presence = PNC.Presence
local Equipment = PNC.Equipment
local Health = PNC.Health
local Network = PNC.Network

local function finalizeNewRecord(record, definition)
    OrderSystem.SetOrder(record, definition.orderSpec)
    if definition.faction == "hostile" then
        OrderSystem.SetHostility(record, {
            mode = "hostile_any_player",
            attackPlayers = true,
            attackNPCs = true,
        })
    end
    Registry.AddRecord(record)
    if definition.forceLive == true then
        record.runtime.forceLive = true
        Presence.Materialize(record, "force_live_spawn")
    end
    Network.BroadcastRecord(record, "spawn")
    return record
end

function API.Spawn(definition)
    local def
    local record
    if not Core.IsAuthority() then
        return nil
    end
    def = Types.NormalizeDefinition(definition)
    record = Types.NewRecord(def)
    return finalizeNewRecord(record, def)
end

function API.Despawn(npcId)
    local record = Registry.Get(npcId)
    if not Core.IsAuthority() or not record then
        return false
    end
    Presence.Abstract(record, "despawn")
    Registry.RemoveRecord(npcId)
    Network.BroadcastRemoval(npcId, "despawn")
    return true
end

function API.SetOrder(npcId, orderSpec)
    local record = Registry.Get(npcId)
    if not record then
        return false
    end
    OrderSystem.SetOrder(record, orderSpec)
    Network.BroadcastRecord(record, "order")
    return true
end

function API.SetHostility(npcId, modeSpec)
    local record = Registry.Get(npcId)
    if not record then
        return false
    end
    OrderSystem.SetHostility(record, modeSpec or {})
    Network.BroadcastRecord(record, "hostility")
    return true
end

function API.ApplyDamage(npcId, damageEvent)
    local record = Registry.Get(npcId)
    local zombie
    if not record then
        return false
    end
    zombie = Registry.GetLiveZombie(npcId)
    Health.ApplyDamage(record, zombie, damageEvent or {})
    Network.BroadcastRecord(record, "damage")
    if record.alive == false then
        Network.BroadcastRemoval(record.id, "death")
    end
    return true
end

function API.GetSnapshot(npcId)
    local record = Registry.Get(npcId)
    if record then
        return Network.BuildSnapshot(record)
    end
    if PNC.Network and PNC.Network.ClientState and PNC.Network.ClientState.snapshots then
        return PNC.Network.ClientState.snapshots[npcId]
    end
    return nil
end

function API.DebugCommand(npcId, command, args)
    local record = Registry.Get(npcId)
    local zombie
    local fullType
    local applied
    local applyReason
    local equipmentInfo
    if not record then
        return false
    end
    if command == "force_live" then
        record.runtime.forceLive = true
        record.runtime.forceAbstract = false
        Presence.Materialize(record, "debug_force_live")
        return true
    end
    if command == "force_abstract" then
        record.runtime.forceAbstract = true
        record.runtime.forceLive = false
        Presence.Abstract(record, "debug_force_abstract")
        return true
    end
    if command == "heal" then
        zombie = Registry.GetLiveZombie(npcId)
        Health.Recover(record, zombie)
        Network.BroadcastRecord(record, "heal")
        return true
    end
    if command == "damage" then
        return API.ApplyDamage(npcId, {
            amount = tonumber(args and args.amount or 10) or 10,
            type = "debug",
        })
    end
    if command == "set_weapon_mode" then
        record.weaponMode = tostring(args and args.weaponMode or record.weaponMode or "melee")
        equipmentInfo = Equipment.Describe(record)
        record.runtime.combatModeResolved = equipmentInfo.combatModeResolved
        record.runtime.weaponStatus = equipmentInfo.weaponStatus
        Network.BroadcastRecord(record, "weapon_mode")
        return true
    end
    if command == "copy_held_weapon" then
        fullType = args and args.weaponFullType or nil
        Core.LogRecordDebug(record, "NPC " .. tostring(npcId) .. " copy_held_weapon requested fullType=" .. tostring(fullType))
        Equipment.SetPrimary(record, fullType)
        zombie = Registry.GetLiveZombie(npcId)
        if zombie then
            applied, applyReason = Equipment.Apply(zombie, record)
            Core.LogRecordDebug(record, "NPC " .. tostring(npcId) .. " equipment apply live=" .. tostring(applied) .. " reason=" .. tostring(applyReason))
        else
            Core.LogRecordDebug(record, "NPC " .. tostring(npcId) .. " has no live body during weapon copy; equipment stored for later materialize")
        end
        if fullType then
            record.weaponMode = Equipment.ResolveWeaponMode(fullType)
        end
        equipmentInfo = Equipment.Describe(record)
        record.runtime.combatModeResolved = equipmentInfo.combatModeResolved
        record.runtime.weaponStatus = equipmentInfo.weaponStatus
        Network.BroadcastRecord(record, "equipment")
        return true
    end
    if command == "toggle_debug" then
        record.runtime.debug = not (record.runtime and record.runtime.debug == true)
        Network.BroadcastRecord(record, "debug_toggle")
        return true
    end
    return false
end
