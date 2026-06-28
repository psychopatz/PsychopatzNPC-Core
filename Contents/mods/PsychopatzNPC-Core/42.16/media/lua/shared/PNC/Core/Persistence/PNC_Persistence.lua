PNC = PNC or {}
PNC.Persistence = PNC.Persistence or {}

local Persistence = PNC.Persistence
local Core = PNC.Core
local Const = PNC.Const
local Identity = PNC.Identity
local Types = PNC.Types
local Inventory = PNC.Inventory

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function normalizeNumber(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = tonumber(fallback)
    end
    if numeric == nil then
        numeric = 0
    end
    return numeric
end

local function copyStringMap(source)
    local output = {}
    local key
    local value
    if type(source) ~= "table" then
        return output
    end
    for key, value in pairs(source) do
        key = normalizeString(key)
        value = normalizeString(value)
        if key and value then
            output[key] = value
        end
    end
    return output
end

local function copyPoints(points, fallbackX, fallbackY, fallbackZ)
    local output = {}
    local i
    local entry
    if type(points) == "table" then
        for i = 1, #points do
            entry = points[i]
            if type(entry) == "table" and entry.x ~= nil and entry.y ~= nil then
                output[#output + 1] = {
                    x = normalizeNumber(entry.x, fallbackX),
                    y = normalizeNumber(entry.y, fallbackY),
                    z = normalizeNumber(entry.z, fallbackZ),
                }
            end
        end
    end
    if #output <= 0 then
        output[1] = {
            x = normalizeNumber(fallbackX, 0),
            y = normalizeNumber(fallbackY, 0),
            z = normalizeNumber(fallbackZ, 0),
        }
    end
    return output
end

local function sanitizeColor(raw)
    if type(raw) ~= "table" then
        return nil
    end
    return {
        r = normalizeNumber(raw.r, 0.2),
        g = normalizeNumber(raw.g, 0.1),
        b = normalizeNumber(raw.b, 0.1),
    }
end

local function sanitizeIdentity(rawIdentity, record)
    local identity = type(rawIdentity) == "table" and Core.DeepCopy(rawIdentity) or {}
    local archetypeID = normalizeString(identity.archetypeID or record.archetypeID)
    local archetypeLabel = normalizeString(identity.archetypeLabel or record.archetypeLabel)
    return {
        seed = Identity.NormalizeSeed(identity.seed or record.identitySeed, record.id),
        archetypeID = archetypeID,
        archetypeLabel = archetypeLabel,
        displayName = normalizeString(identity.displayName or record.name),
        isFemale = identity.isFemale == true or record.isFemale == true,
        survivor = {
            forename = normalizeString(identity.survivor and identity.survivor.forename),
            surname = normalizeString(identity.survivor and identity.survivor.surname),
            hairModel = normalizeString(identity.survivor and identity.survivor.hairModel),
            beardModel = normalizeString(identity.survivor and identity.survivor.beardModel),
            hairColor = sanitizeColor(identity.survivor and identity.survivor.hairColor),
            skinTexture = normalizeString(identity.survivor and identity.survivor.skinTexture),
            voice = normalizeString(identity.survivor and identity.survivor.voice),
        },
    }
end

local function sanitizeOrderSpec(orderSpec, record)
    local spec = type(orderSpec) == "table" and Core.DeepCopy(orderSpec) or nil
    if not spec then
        return nil
    end
    if spec.points then
        spec.points = copyPoints(spec.points, record.anchorX, record.anchorY, record.anchorZ)
    end
    if spec.x ~= nil then
        spec.x = normalizeNumber(spec.x, record.anchorX)
    end
    if spec.y ~= nil then
        spec.y = normalizeNumber(spec.y, record.anchorY)
    end
    if spec.z ~= nil then
        spec.z = normalizeNumber(spec.z, record.anchorZ)
    end
    spec.ownerUsername = normalizeString(spec.ownerUsername)
    spec.ownerOnlineID = nil
    return spec
end

local function sanitizeHealth(rawHealth, fallbackMax)
    local maxValue = math.max(1, normalizeNumber(rawHealth and rawHealth.max, fallbackMax or Const.DEFAULT_HP_MAX))
    local currentValue = Core.Clamp(normalizeNumber(rawHealth and rawHealth.current, maxValue), 0, maxValue)
    return {
        current = currentValue,
        max = maxValue,
        state = tostring(rawHealth and rawHealth.state or "normal"),
        lastDamageAt = normalizeNumber(rawHealth and rawHealth.lastDamageAt, 0),
        downedAt = normalizeNumber(rawHealth and rawHealth.downedAt, 0),
        recentDamageUntil = normalizeNumber(rawHealth and rawHealth.recentDamageUntil, 0),
        reviveUntil = normalizeNumber(rawHealth and rawHealth.reviveUntil, 0),
    }
end

local function sanitizeStamina(rawStamina, record)
    local output
    if type(rawStamina) ~= "table" then
        return nil
    end
    output = {
        current = normalizeNumber(rawStamina.current, 0),
        max = normalizeNumber(rawStamina.max, 0),
        state = tostring(rawStamina.state or "fresh"),
        visibleUntil = normalizeNumber(rawStamina.visibleUntil, 0),
    }
    if record then
        record.stamina = output
        if PNC.Stamina and PNC.Stamina.BuildSnapshot then
            output = Core.DeepCopy(PNC.Stamina.BuildSnapshot(record))
            record.stamina = output
        end
    end
    return output
end

local function sanitizeProgression(rawProgression)
    local output = {
        recruited = false,
        skillLevels = {},
        skillXP = {},
    }
    local key
    local value
    local source = type(rawProgression) == "table" and rawProgression or {}
    output.recruited = source.recruited == true
    if type(source.skillLevels) == "table" then
        for key, value in pairs(source.skillLevels) do
            output.skillLevels[tostring(key)] = math.max(0, math.min(10, math.floor(normalizeNumber(value, 0))))
        end
    end
    if type(source.skillXP) == "table" then
        for key, value in pairs(source.skillXP) do
            output.skillXP[tostring(key)] = math.max(0, normalizeNumber(value, 0))
        end
    end
    return output
end

local function sanitizeHostility(rawHostility, faction)
    local hostile = tostring(faction or "") == "hostile"
    local source = type(rawHostility) == "table" and rawHostility or {}
    return {
        mode = tostring(source.mode or (hostile and "hostile_any_player" or "defend_owner")),
        attackPlayers = source.attackPlayers == true or hostile,
        attackNPCs = source.attackNPCs ~= false,
        attackZombies = source.attackZombies ~= false,
    }
end

local function migrateLegacyIdentity(raw, definition)
    if type(raw.identity) == "table" then
        return Core.DeepCopy(raw.identity)
    end
    return {
        seed = raw.identitySeed,
        archetypeID = raw.archetypeID,
        archetypeLabel = raw.archetypeLabel,
        displayName = raw.displayName or raw.name,
        isFemale = raw.isFemale == true,
        survivor = {
            hairModel = raw.hairModel,
            beardModel = raw.beardModel,
            skinTexture = raw.skinTexture,
            hairColor = sanitizeColor(raw.hairColor),
            voice = raw.voice,
            forename = raw.forename,
            surname = raw.surname,
        },
    }
end

local function migrateLegacyInventory(raw)
    if type(raw.inventory) == "table" then
        return Core.DeepCopy(raw.inventory)
    end
    if type(raw.equipment) == "table" then
        return nil
    end
    return nil
end

function Persistence.RebuildRuntime(record)
    local now = Core.Now()
    local healthState
    if not record then
        return nil
    end
    record.runtime = {
        target = nil,
        pathing = nil,
        abstractTravel = nil,
        roamGoalX = nil,
        roamGoalY = nil,
        roamGoalZ = nil,
        lastPathX = nil,
        lastPathY = nil,
        lastAttackAt = 0,
        lastZombieAttackAt = 0,
        inCombatUntil = 0,
        targetKind = "none",
        combatModeResolved = tostring(record.weaponMode or "melee"),
        weaponStatus = "barehand",
        combatBlockReason = "rehydrated",
        ownerSneaking = false,
        stealthActive = false,
        stealthBroken = false,
        stealthReason = "loaded",
        forceLive = false,
        forceAbstract = false,
        debug = false,
    }
    record.activeJob = nil
    record.activeBehavior = nil
    record.liveBodyInstanceID = nil
    record.lastThinkAt = now
    record.nextThinkAt = now
    record.lastSyncAt = 0
    record.presenceRevision = normalizeNumber(record.presenceRevision, 0)
    record.ownerOnlineID = nil
    healthState = record.health and tostring(record.health.state or "normal") or "normal"
    if record.alive == false or healthState == "corpse" then
        record.presenceState = Const.PRESENCE_CORPSE
    else
        record.presenceState = Const.PRESENCE_ABSTRACT
    end
    if record.stamina then
        record.stamina.lastUpdatedAt = now
    end
    return record
end

function Persistence.SerializeRecord(record)
    local identity
    local progression
    local payload
    if not record or record.persist == false then
        return nil
    end
    if Inventory and Inventory.EnsureRecordInventory then
        Inventory.EnsureRecordInventory(record)
    end
    identity = sanitizeIdentity(record.identity, record)
    progression = sanitizeProgression(record.progression)
    progression.recruited = record.recruited == true
    payload = {
        schemaVersion = Const.PERSISTENCE_VERSION,
        id = record.id,
        persist = record.persist ~= false,
        faction = record.faction,
        ownerUsername = normalizeString(record.ownerUsername),
        identity = identity,
        position = {
            x = normalizeNumber(record.x, 0),
            y = normalizeNumber(record.y, 0),
            z = normalizeNumber(record.z, 0),
        },
        spawn = {
            x = normalizeNumber(record.spawnX, record.x),
            y = normalizeNumber(record.spawnY, record.y),
            z = normalizeNumber(record.spawnZ, record.z),
        },
        anchor = {
            x = normalizeNumber(record.anchorX, record.x),
            y = normalizeNumber(record.anchorY, record.y),
            z = normalizeNumber(record.anchorZ, record.z),
        },
        presenceState = record.alive == false and Const.PRESENCE_CORPSE or Const.PRESENCE_ABSTRACT,
        orderSpec = sanitizeOrderSpec(record.orderSpec, record),
        patrolPoints = copyPoints(record.patrolPoints, record.anchorX, record.anchorY, record.anchorZ),
        patrolIndex = math.max(1, math.floor(normalizeNumber(record.patrolIndex, 1))),
        hostility = sanitizeHostility(record.hostility, record.faction),
        health = sanitizeHealth(record.health, record.health and record.health.max or Const.DEFAULT_HP_MAX),
        stamina = sanitizeStamina(record.stamina, record),
        weaponMode = tostring(record.weaponMode or "melee"),
        equipment = {
            primaryFullType = normalizeString(record.equipment and record.equipment.primaryFullType),
            secondaryFullType = normalizeString(record.equipment and record.equipment.secondaryFullType),
            worn = copyStringMap(record.equipment and record.equipment.worn),
            attached = copyStringMap(record.equipment and record.equipment.attached),
        },
        inventory = Inventory and Inventory.Serialize and Inventory.Serialize(record) or nil,
        progression = progression,
    }
    return payload
end

function Persistence.DeserializeRecord(raw, fallbackID)
    local definition
    local position
    local spawn
    local anchor
    local record
    local identity
    local progression
    local inventoryData
    if type(raw) ~= "table" then
        return nil
    end
    position = raw.position or raw
    spawn = raw.spawn or raw
    anchor = raw.anchor or raw
    identity = migrateLegacyIdentity(raw)
    inventoryData = migrateLegacyInventory(raw)
    definition = {
        id = raw.id or fallbackID,
        displayName = raw.displayName or raw.name or (identity and identity.displayName) or nil,
        name = raw.displayName or raw.name or (identity and identity.displayName) or nil,
        faction = raw.faction,
        visualProfile = raw.visualProfile,
        outfit = raw.outfit,
        isFemale = raw.isFemale == true or (identity and identity.isFemale == true),
        x = normalizeNumber(position.x, raw.x or 0),
        y = normalizeNumber(position.y, raw.y or 0),
        z = normalizeNumber(position.z, raw.z or 0),
        anchorX = normalizeNumber(anchor.x, raw.anchorX or raw.x or 0),
        anchorY = normalizeNumber(anchor.y, raw.anchorY or raw.y or 0),
        anchorZ = normalizeNumber(anchor.z, raw.anchorZ or raw.z or 0),
        ownerUsername = normalizeString(raw.ownerUsername),
        identitySeed = raw.identitySeed or (identity and identity.seed) or nil,
        identity = identity,
        orderSpec = raw.orderSpec,
        patrolPoints = raw.patrolPoints,
        weaponMode = raw.weaponMode,
        combatProfile = raw.combatProfile,
        equipment = raw.equipment,
        inventory = inventoryData,
        allowedJobs = raw.allowedJobs,
        archetypeID = raw.archetypeID or (identity and identity.archetypeID) or nil,
        persist = raw.persist ~= false,
        recruited = raw.recruited == true or (raw.progression and raw.progression.recruited == true) or false,
    }
    record = Types.NewRecord(definition)
    if not record then
        return nil
    end
    record.id = tostring(raw.id or record.id)
    record.x = normalizeNumber(position.x, record.x)
    record.y = normalizeNumber(position.y, record.y)
    record.z = normalizeNumber(position.z, record.z)
    record.spawnX = normalizeNumber(spawn.x, raw.spawnX or record.x)
    record.spawnY = normalizeNumber(spawn.y, raw.spawnY or record.y)
    record.spawnZ = normalizeNumber(spawn.z, raw.spawnZ or record.z)
    record.anchorX = normalizeNumber(anchor.x, record.anchorX)
    record.anchorY = normalizeNumber(anchor.y, record.anchorY)
    record.anchorZ = normalizeNumber(anchor.z, record.anchorZ)
    record.ownerUsername = normalizeString(raw.ownerUsername) or record.ownerUsername
    record.weaponMode = tostring(raw.weaponMode or record.weaponMode or "melee")
    record.patrolPoints = copyPoints(raw.patrolPoints or record.patrolPoints, record.anchorX, record.anchorY, record.anchorZ)
    record.patrolIndex = math.max(1, math.floor(normalizeNumber(raw.patrolIndex, 1)))
    record.orderSpec = sanitizeOrderSpec(raw.orderSpec, record)
    record.hostility = sanitizeHostility(raw.hostility, record.faction)
    record.health = sanitizeHealth(raw.health or raw, record.health and record.health.max or Const.DEFAULT_HP_MAX)
    record.alive = tostring(record.health.state or "") ~= "dead"
        and tostring(record.health.state or "") ~= "corpse"
        and tostring(raw.presenceState or "") ~= Const.PRESENCE_CORPSE
    progression = sanitizeProgression(raw.progression)
    record.progression = {
        skillLevels = progression.skillLevels,
        skillXP = progression.skillXP,
    }
    record.recruited = progression.recruited == true or record.recruited == true
    record.persist = raw.persist ~= false
    Identity.ApplyRecordIdentity(record, {
        archetypeID = raw.archetypeID or record.archetypeID,
        identitySeed = identity and identity.seed or record.identitySeed,
        identity = identity,
        displayName = raw.displayName or raw.name,
        name = raw.displayName or raw.name,
        visualProfile = raw.visualProfile,
        outfit = raw.outfit,
        isFemale = raw.isFemale == true or (identity and identity.isFemale == true),
    })
    sanitizeStamina(raw.stamina, record)
    if Inventory and Inventory.Deserialize then
        Inventory.Deserialize(record, raw.inventory)
        if not raw.inventory and type(raw.equipment) == "table" and Inventory.SyncFromEquipment then
            Inventory.SyncFromEquipment(record, "legacy_equipment_load")
        end
    end
    return Persistence.RebuildRuntime(record)
end

function Persistence.LoadAll(serializedRecords)
    local output = {}
    local id
    local raw
    local record
    if type(serializedRecords) ~= "table" then
        return output
    end
    for id, raw in pairs(serializedRecords) do
        record = Persistence.DeserializeRecord(raw, id)
        if record and record.id then
            output[record.id] = record
        end
    end
    return output
end

function Persistence.SaveAll(records)
    local output = {}
    local id
    local raw
    if type(records) ~= "table" then
        return output
    end
    for id, raw in pairs(records) do
        raw = Persistence.SerializeRecord(raw)
        if raw then
            output[id] = raw
        end
    end
    return output
end
