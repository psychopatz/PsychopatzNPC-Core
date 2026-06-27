PNC = PNC or {}
PNC.Types = PNC.Types or {}

local Types = PNC.Types
local Core = PNC.Core
local Const = PNC.Const

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

    return {
        id = def.id,
        name = tostring(def.name or (isHostile and "Hostile NPC" or "Companion NPC")),
        faction = faction,
        outfit = def.outfit and tostring(def.outfit) or nil,
        visualProfile = tostring(def.visualProfile or faction),
        isFemale = def.isFemale == true,
        x = x,
        y = y,
        z = z,
        hpMax = tonumber(def.hpMax) or Const.DEFAULT_HP_MAX,
        anchorX = tonumber(def.anchorX) or x,
        anchorY = tonumber(def.anchorY) or y,
        anchorZ = tonumber(def.anchorZ) or z,
        ownerUsername = def.ownerUsername,
        ownerOnlineID = def.ownerOnlineID,
        orderSpec = def.orderSpec,
        patrolPoints = normalizePatrolPoints(def.patrolPoints, x, y, z),
        weaponMode = tostring(def.weaponMode or (isHostile and "mixed" or "melee")),
        combatProfile = Core.DeepCopy(def.combatProfile or {}),
        equipment = Core.DeepCopy(def.equipment or {}),
        allowedJobs = Core.DeepCopy(def.allowedJobs or {}),
        forceLive = def.forceLive == true,
        debug = def.debug == true,
    }
end

function Types.NewRecord(definition)
    local def = Types.NormalizeDefinition(definition)
    local now = Core.Now()
    local hostile = def.faction == "hostile"
    local record = {
        id = def.id or Core.GenerateID("npc"),
        name = def.name,
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
        equipment = Core.DeepCopy(def.equipment or {}),
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

    return record
end
