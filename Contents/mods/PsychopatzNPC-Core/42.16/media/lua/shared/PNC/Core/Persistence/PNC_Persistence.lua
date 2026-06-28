PNC = PNC or {}
PNC.Persistence = PNC.Persistence or {}

local Persistence = PNC.Persistence
local Core = PNC.Core
local Const = PNC.Const
local Identity = PNC.Identity
local Types = PNC.Types

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function normalizeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then
        return tonumber(fallback) or 0
    end
    return number
end

local function copyMap(source)
    local output = {}
    local key
    local value
    if type(source) ~= "table" then
        return output
    end
    for key, value in pairs(source) do
        output[tostring(key)] = tostring(value)
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
    if spec.ownerUsername ~= nil then
        spec.ownerUsername = normalizeString(spec.ownerUsername)
    end
    spec.ownerOnlineID = nil
    return spec
end

local function sanitizeHealth(rawHealth, hpMax)
    local maxValue = math.max(1, normalizeNumber(rawHealth and rawHealth.max or nil, hpMax or Const.DEFAULT_HP_MAX))
    local current = normalizeNumber(rawHealth and rawHealth.current or nil, maxValue)
    return {
        current = Core.Clamp(current, 0, maxValue),
        max = maxValue,
        state = tostring(rawHealth and rawHealth.state or "normal"),
        lastDamageAt = normalizeNumber(rawHealth and rawHealth.lastDamageAt or nil, 0),
        downedAt = normalizeNumber(rawHealth and rawHealth.downedAt or nil, 0),
        recentDamageUntil = normalizeNumber(rawHealth and rawHealth.recentDamageUntil or nil, 0),
        reviveUntil = normalizeNumber(rawHealth and rawHealth.reviveUntil or nil, 0),
    }
end

local function sanitizeStamina(rawStamina)
    if type(rawStamina) ~= "table" then
        return nil
    end
    return {
        current = normalizeNumber(rawStamina.current, nil),
        max = normalizeNumber(rawStamina.max, nil),
        state = tostring(rawStamina.state or "fresh"),
        visibleUntil = normalizeNumber(rawStamina.visibleUntil, 0),
    }
end

local function sanitizeProgression(rawProgression)
    local output = {
        skillXP = {},
        skillLevels = {},
    }
    local key
    local value
    local source = type(rawProgression) == "table" and rawProgression or {}
    if type(source.skillXP) == "table" then
        for key, value in pairs(source.skillXP) do
            output.skillXP[tostring(key)] = math.max(0, normalizeNumber(value, 0))
        end
    end
    if type(source.skillLevels) == "table" then
        for key, value in pairs(source.skillLevels) do
            output.skillLevels[tostring(key)] = math.max(0, math.min(10, math.floor(normalizeNumber(value, 0))))
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
    if record.alive == false then
        record.presenceState = Const.PRESENCE_CORPSE
    elseif healthState == "corpse" then
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
    local payload
    if not record or record.persist == false then
        return nil
    end
    payload = {
        schemaVersion = Const.PERSISTENCE_VERSION,
        id = record.id,
        identitySeed = record.identitySeed,
        archetypeID = record.archetypeID,
        displayName = record.name,
        isFemale = record.isFemale == true,
        faction = record.faction,
        visualProfile = record.visualProfile,
        outfit = record.outfit,
        ownerUsername = record.ownerUsername,
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
        alive = record.alive ~= false,
        orderSpec = sanitizeOrderSpec(record.orderSpec, record),
        patrolPoints = copyPoints(record.patrolPoints, record.anchorX, record.anchorY, record.anchorZ),
        patrolIndex = math.max(1, math.floor(normalizeNumber(record.patrolIndex, 1))),
        hostility = sanitizeHostility(record.hostility, record.faction),
        health = sanitizeHealth(record.health, record.health and record.health.max or Const.DEFAULT_HP_MAX),
        stamina = sanitizeStamina(record.stamina),
        weaponMode = tostring(record.weaponMode or "melee"),
        equipment = {
            primaryFullType = normalizeString(record.equipment and record.equipment.primaryFullType or nil),
            secondaryFullType = normalizeString(record.equipment and record.equipment.secondaryFullType or nil),
            worn = copyMap(record.equipment and record.equipment.worn or nil),
            attached = copyMap(record.equipment and record.equipment.attached or nil),
        },
        progression = sanitizeProgression(record.progression),
        recruited = record.recruited == true,
        persist = record.persist ~= false,
    }
    return payload
end

function Persistence.DeserializeRecord(raw, fallbackID)
    local position
    local anchor
    local spawn
    local record
    local definition
    if type(raw) ~= "table" then
        return nil
    end
    position = raw.position or raw
    anchor = raw.anchor or raw
    spawn = raw.spawn or raw
    definition = {
        id = raw.id or fallbackID,
        name = raw.displayName or raw.name,
        displayName = raw.displayName or raw.name,
        faction = raw.faction,
        visualProfile = raw.visualProfile,
        outfit = raw.outfit,
        isFemale = raw.isFemale,
        x = normalizeNumber(position.x, raw.x or 0),
        y = normalizeNumber(position.y, raw.y or 0),
        z = normalizeNumber(position.z, raw.z or 0),
        anchorX = normalizeNumber(anchor.x, raw.anchorX or raw.x or 0),
        anchorY = normalizeNumber(anchor.y, raw.anchorY or raw.y or 0),
        anchorZ = normalizeNumber(anchor.z, raw.anchorZ or raw.z or 0),
        ownerUsername = normalizeString(raw.ownerUsername),
        identitySeed = raw.identitySeed,
        orderSpec = raw.orderSpec,
        patrolPoints = raw.patrolPoints,
        weaponMode = raw.weaponMode,
        combatProfile = raw.combatProfile,
        equipment = raw.equipment,
        allowedJobs = raw.allowedJobs,
        archetypeID = raw.archetypeID,
        persist = raw.persist ~= false,
        recruited = raw.recruited == true,
    }
    record = Types.NewRecord(definition)
    if not record then
        return nil
    end
    record.id = tostring(raw.id or record.id)
    record.identitySeed = Identity.NormalizeSeed(raw.identitySeed or record.identitySeed, record.id)
    record.name = normalizeString(raw.displayName or raw.name or record.name) or record.name
    record.archetypeID = raw.archetypeID or record.archetypeID
    record.archetypeLabel = normalizeString(raw.archetypeLabel) or record.archetypeLabel
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
    record.patrolPoints = copyPoints(raw.patrolPoints or record.patrolPoints, record.anchorX, record.anchorY, record.anchorZ)
    record.patrolIndex = math.max(1, math.floor(normalizeNumber(raw.patrolIndex, 1)))
    record.orderSpec = sanitizeOrderSpec(raw.orderSpec, record)
    record.hostility = sanitizeHostility(raw.hostility, record.faction)
    record.health = sanitizeHealth(raw.health or raw, record.health and record.health.max or Const.DEFAULT_HP_MAX)
    record.stamina = sanitizeStamina(raw.stamina) or record.stamina
    record.progression = sanitizeProgression(raw.progression)
    record.recruited = raw.recruited == true or record.recruited == true
    record.persist = raw.persist ~= false
    record.alive = raw.alive ~= false
        and tostring(record.health.state or "") ~= "dead"
        and tostring(record.health.state or "") ~= "corpse"
        and tostring(raw.presenceState or "") ~= Const.PRESENCE_CORPSE
    Identity.ApplyRecordIdentity(record, record)
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
