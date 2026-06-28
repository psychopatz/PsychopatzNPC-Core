PNC = PNC or {}
PNC.Network = PNC.Network or {}
PNC.Network.ClientState = PNC.Network.ClientState or {
    snapshots = {},
    characterPayloads = {},
}

local Network = PNC.Network
local Core = PNC.Core
local Const = PNC.Const
local Equipment = PNC.Equipment
local Inventory = PNC.Inventory
local Skills = PNC.Skills
local Stamina = PNC.Stamina

local function resolveAIState(record)
    local healthState = record.health and tostring(record.health.state or "normal") or "normal"
    local hasTarget = record.runtime and record.runtime.target ~= nil
    local inCombat = hasTarget
        or ((tonumber(record.runtime and record.runtime.inCombatUntil or 0) or 0) > Core.Now())
    if record.alive == false then
        return "Dead", false
    end
    if healthState == "incapacitated" then
        return "Downed", true
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

local function buildIdentitySummary(record)
    local summary = PNC.Identity and PNC.Identity.GetCharacterSummary and PNC.Identity.GetCharacterSummary(record) or {}
    return {
        displayName = summary.displayName or record.name,
        archetypeID = summary.archetypeID or record.archetypeID,
        archetypeLabel = summary.archetypeLabel or record.archetypeLabel,
        identitySeed = summary.identitySeed or record.identitySeed,
        isFemale = summary.isFemale == true or record.isFemale == true,
        survivor = Core.DeepCopy(summary.survivor or {}),
    }
end

local function buildCombatSummary(record)
    local target = record.runtime and record.runtime.target or nil
    local equipmentInfo = Equipment and Equipment.Describe and Equipment.Describe(record) or {}
    return {
        targetKind = target and target.kind or "none",
        combatModeResolved = equipmentInfo.combatModeResolved or record.weaponMode,
        weaponStatus = equipmentInfo.weaponStatus or "unknown",
        combatBlockReason = record.runtime and record.runtime.combatBlockReason or nil,
    }
end

function Network.BuildRosterSnapshot(record)
    local aiState
    local inCombat
    local staminaInfo
    local identity
    aiState, inCombat = resolveAIState(record)
    staminaInfo = Stamina and Stamina.BuildSnapshot and Stamina.BuildSnapshot(record) or {}
    identity = buildIdentitySummary(record)
    return {
        id = record.id,
        displayName = identity.displayName,
        name = identity.displayName,
        archetypeID = identity.archetypeID,
        archetypeLabel = identity.archetypeLabel,
        identitySeed = identity.identitySeed,
        faction = record.faction,
        presenceState = record.presenceState,
        x = record.x,
        y = record.y,
        z = record.z,
        orderKind = record.orderSpec and record.orderSpec.kind or nil,
        hpCurrent = record.health and record.health.current or nil,
        hpMax = record.health and record.health.max or nil,
        healthState = record.health and record.health.state or nil,
        staminaCurrent = staminaInfo.current,
        staminaMax = staminaInfo.max,
        staminaState = staminaInfo.state,
        aiState = aiState,
        inCombat = inCombat,
        recruited = record.recruited == true,
        persist = record.persist ~= false,
    }
end

function Network.BuildSnapshot(record)
    local aiState
    local inCombat
    local staminaInfo
    local equipmentInfo
    local identity
    local inventorySummary
    local combat
    aiState, inCombat = resolveAIState(record)
    staminaInfo = Stamina and Stamina.BuildSnapshot and Stamina.BuildSnapshot(record) or {}
    equipmentInfo = Equipment and Equipment.Describe and Equipment.Describe(record) or {}
    identity = buildIdentitySummary(record)
    inventorySummary = Inventory and Inventory.BuildSummaryPayload and Inventory.BuildSummaryPayload(record) or nil
    combat = buildCombatSummary(record)
    return {
        id = record.id,
        name = identity.displayName,
        displayName = identity.displayName,
        identitySeed = identity.identitySeed,
        archetypeID = identity.archetypeID,
        archetypeLabel = identity.archetypeLabel,
        recruited = record.recruited == true,
        persist = record.persist ~= false,
        faction = record.faction,
        visualProfile = record.visualProfile,
        isFemale = identity.isFemale,
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
        canRevive = record.health and record.health.state == "incapacitated" and (tonumber(record.health.reviveUntil) or 0) > Core.Now() or false,
        reviveUntil = record.health and record.health.reviveUntil or 0,
        recentDamageUntil = record.health and record.health.recentDamageUntil or 0,
        staminaCurrent = staminaInfo.current,
        staminaMax = staminaInfo.max,
        staminaState = staminaInfo.state,
        staminaVisibleUntil = staminaInfo.visibleUntil,
        staminaRatio = math.max(0, math.min(1, (tonumber(staminaInfo.current) or 0) / math.max(1, tonumber(staminaInfo.max) or 1))),
        skillLevels = Skills and Skills.BuildSnapshot and Skills.BuildSnapshot(record) or {},
        weaponMode = record.weaponMode,
        weaponFullType = record.equipment and record.equipment.primaryFullType or nil,
        combatModeResolved = equipmentInfo.combatModeResolved or record.weaponMode,
        weaponStatus = equipmentInfo.weaponStatus or "unknown",
        presenceRevision = record.presenceRevision,
        aiState = aiState,
        inCombat = inCombat,
        equipmentSummary = {
            primaryFullType = record.equipment and record.equipment.primaryFullType or nil,
            secondaryFullType = record.equipment and record.equipment.secondaryFullType or nil,
            worn = Core.DeepCopy(record.equipment and record.equipment.worn or {}),
            attached = Core.DeepCopy(record.equipment and record.equipment.attached or {}),
        },
        inventorySummary = inventorySummary,
        characterWindow = {
            displayName = identity.displayName,
            archetypeID = identity.archetypeID,
            archetypeLabel = identity.archetypeLabel,
            identitySeed = identity.identitySeed,
            ownerUsername = record.ownerUsername,
            recruited = record.recruited == true,
            canRevive = record.health and record.health.state == "incapacitated" and (tonumber(record.health.reviveUntil) or 0) > Core.Now() or false,
            carry = inventorySummary,
        },
        debugState = {
            aiState = aiState,
            activeJob = record.activeJob,
            activeBehavior = record.activeBehavior,
            orderKind = record.orderSpec and record.orderSpec.kind or nil,
            targetKind = combat.targetKind,
            healthState = record.health and record.health.state or nil,
            canRevive = record.health and record.health.state == "incapacitated" and (tonumber(record.health.reviveUntil) or 0) > Core.Now() or false,
            weaponMode = record.weaponMode,
            combatModeResolved = combat.combatModeResolved,
            weaponStatus = combat.weaponStatus,
            combatBlockReason = combat.combatBlockReason,
            staminaState = staminaInfo.state,
            staminaCurrent = staminaInfo.current,
            staminaMax = staminaInfo.max,
            stealthActive = record.runtime and record.runtime.stealthActive == true or false,
            debugEnabled = record.runtime and record.runtime.debug == true or false,
            presenceState = record.presenceState,
        },
    }
end

function Network.BuildCharacterPayload(record)
    local snapshot = Network.BuildSnapshot(record)
    local inventoryPayload = Inventory and Inventory.BuildFullPayload and Inventory.BuildFullPayload(record) or nil
    local identity = buildIdentitySummary(record)
    return {
        npcId = record.id,
        revision = record.presenceRevision,
        snapshot = snapshot,
        identity = identity,
        health = Core.DeepCopy(record.health or {}),
        stamina = Stamina and Stamina.BuildSnapshot and Stamina.BuildSnapshot(record) or {},
        inventory = inventoryPayload,
        equipment = Core.DeepCopy(record.equipment or {}),
        progression = {
            recruited = record.recruited == true,
            skillLevels = Skills and Skills.BuildSnapshot and Skills.BuildSnapshot(record) or {},
            skillXP = Core.DeepCopy(record.progression and record.progression.skillXP or {}),
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

function Network.SendCharacterPayload(targetPlayer, record)
    local payload
    if not record then
        return
    end
    payload = Network.BuildCharacterPayload(record)
    if not payload then
        return
    end
    if isServer and isServer() and targetPlayer then
        sendServerCommand(targetPlayer, Const.MODULE, Const.CMD_CHARACTER_PAYLOAD, payload)
    elseif not isServer or not isServer() then
        triggerEvent("OnServerCommand", Const.MODULE, Const.CMD_CHARACTER_PAYLOAD, payload)
    end
end
