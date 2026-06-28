PNC = PNC or {}
PNC.Types = PNC.Types or {}

local Types = PNC.Types
local Core = PNC.Core
local Const = PNC.Const
local Identity = PNC.Identity

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function normalizeStringMap(source)
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

local function normalizeEquipment(equipment)
    local source = type(equipment) == "table" and equipment or {}
    return {
        primaryFullType = normalizeString(source.primaryFullType),
        secondaryFullType = normalizeString(source.secondaryFullType),
        worn = normalizeStringMap(source.worn),
        attached = normalizeStringMap(source.attached),
    }
end

local function normalizePatrolPoints(points, fallbackX, fallbackY, fallbackZ)
    local output = {}
    local i
    local entry
    if type(points) == "table" then
        for i = 1, #points do
            entry = points[i]
            if type(entry) == "table" and entry.x ~= nil and entry.y ~= nil then
                output[#output + 1] = {
                    x = tonumber(entry.x) or fallbackX or 0,
                    y = tonumber(entry.y) or fallbackY or 0,
                    z = tonumber(entry.z) or fallbackZ or 0,
                }
            end
        end
    end
    if #output <= 0 then
        output[1] = { x = fallbackX or 0, y = fallbackY or 0, z = fallbackZ or 0 }
    end
    return output
end

function Types.NormalizeDefinition(definition)
    local def = definition or {}
    local faction = tostring(def.faction or def.role or "companion")
    local x = tonumber(def.x) or 0
    local y = tonumber(def.y) or 0
    local z = tonumber(def.z) or 0
    local isHostile = faction == "hostile"
    local explicitName = normalizeString(def.displayName or def.name)

    return {
        id = def.id,
        name = explicitName,
        displayName = explicitName,
        archetypeID = normalizeString(def.archetypeID),
        faction = faction,
        outfit = def.outfit and tostring(def.outfit) or nil,
        visualProfile = normalizeString(def.visualProfile),
        isFemale = def.isFemale == nil and nil or def.isFemale == true,
        x = x,
        y = y,
        z = z,
        hpMax = tonumber(def.hpMax) or Const.DEFAULT_HP_MAX,
        anchorX = tonumber(def.anchorX) or x,
        anchorY = tonumber(def.anchorY) or y,
        anchorZ = tonumber(def.anchorZ) or z,
        ownerUsername = def.ownerUsername,
        ownerOnlineID = def.ownerOnlineID,
        identitySeed = tonumber(def.identitySeed) or nil,
        orderSpec = def.orderSpec,
        patrolPoints = normalizePatrolPoints(def.patrolPoints, x, y, z),
        weaponMode = tostring(def.weaponMode or (isHostile and "mixed" or "melee")),
        combatProfile = Core.DeepCopy(def.combatProfile or {}),
        equipment = normalizeEquipment(def.equipment),
        allowedJobs = Core.DeepCopy(def.allowedJobs or {}),
        forceLive = def.forceLive == true,
        debug = def.debug == true,
        persist = def.persist ~= false,
        recruited = def.recruited == true,
    }
end

function Types.NewRecord(definition)
    local def = Types.NormalizeDefinition(definition)
    local now = Core.Now()
    local hostile = def.faction == "hostile"
    local generatedID = def.id or Core.GenerateID("npc")
    local record = {
        id = generatedID,
        name = def.displayName,
        identitySeed = Identity and Identity.NormalizeSeed(
            def.identitySeed,
            tostring(def.displayName or def.name or def.archetypeID or def.faction or "PNC NPC") .. ":" .. tostring(generatedID)
        ) or (tonumber(def.identitySeed) or 1),
        archetypeID = def.archetypeID,
        archetypeLabel = nil,
        faction = def.faction,
        outfit = def.outfit,
        visualProfile = def.visualProfile,
        isFemale = def.isFemale,
        x = def.x,
        y = def.y,
        z = def.z,
        spawnX = def.x,
        spawnY = def.y,
        spawnZ = def.z,
        anchorX = def.anchorX,
        anchorY = def.anchorY,
        anchorZ = def.anchorZ,
        ownerUsername = def.ownerUsername,
        ownerOnlineID = def.ownerOnlineID,
        allowedJobs = def.allowedJobs,
        patrolPoints = def.patrolPoints,
        patrolIndex = 1,
        weaponMode = def.weaponMode,
        equipment = normalizeEquipment(def.equipment),
        combatProfile = {
            meleeDamage = tonumber(def.combatProfile.meleeDamage) or 10,
            rangedDamage = tonumber(def.combatProfile.rangedDamage) or 7,
            meleeCooldownMs = tonumber(def.combatProfile.meleeCooldownMs) or 900,
            rangedCooldownMs = tonumber(def.combatProfile.rangedCooldownMs) or 1800,
            unarmedDamage = tonumber(def.combatProfile.unarmedDamage) or Const.UNARMED_DAMAGE,
            unarmedGroundDamage = tonumber(def.combatProfile.unarmedGroundDamage) or Const.UNARMED_GROUND_DAMAGE,
            unarmedCooldownMs = tonumber(def.combatProfile.unarmedCooldownMs) or Const.UNARMED_COOLDOWN_MS,
        },
        hostility = {
            mode = hostile and "hostile_any_player" or "defend_owner",
            attackPlayers = hostile,
            attackNPCs = true,
            attackZombies = true,
        },
        health = {
            current = def.hpMax,
            max = def.hpMax,
            state = "normal",
            lastDamageAt = 0,
            downedAt = 0,
            recentDamageUntil = 0,
        },
        presenceState = Const.PRESENCE_ABSTRACT,
        alive = true,
        orderSpec = nil,
        activeJob = nil,
        activeBehavior = nil,
        presenceRevision = 0,
        lastThinkAt = now,
        nextThinkAt = now,
        lastSyncAt = 0,
        liveBodyInstanceID = nil,
        recruited = def.ownerOnlineID ~= nil or def.ownerUsername ~= nil or def.recruited == true,
        persist = def.persist ~= false,
        runtime = {
            target = nil,
            lastPathX = nil,
            lastPathY = nil,
            lastAttackAt = 0,
            lastZombieAttackAt = 0,
            targetKind = "none",
            combatModeResolved = tostring(def.weaponMode or (hostile and "mixed" or "melee")),
            weaponStatus = "barehand",
            combatBlockReason = "spawned",
            ownerSneaking = false,
            stealthActive = false,
            stealthBroken = false,
            stealthReason = "spawned",
            debug = def.debug == true,
        },
    }

    if Identity and Identity.ApplyRecordIdentity then
        Identity.ApplyRecordIdentity(record, def)
    else
        record.name = record.name or (hostile and "Hostile NPC" or "Companion NPC")
    end

    return record
end
