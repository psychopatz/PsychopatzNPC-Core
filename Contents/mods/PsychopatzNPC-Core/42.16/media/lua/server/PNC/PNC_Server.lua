if isClient() and not isServer() then
    return
end

PNC = PNC or {}
PNC.Server = PNC.Server or {}

local Server = PNC.Server
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry
local Spatial = PNC.SpatialIndex
local Presence = PNC.Presence
local Health = PNC.Health
local Behavior = PNC.BehaviorSystem
local PathService = PNC.PathService
local Scheduler = PNC.Scheduler
local Network = PNC.Network
local API = PNC.API
local ZombieAggro = PNC.ZombieAggro
local Stamina = PNC.Stamina
local Archetypes = PNC.Archetypes
local Animation = PNC.Animation

local function resolveDebugArchetype(args, faction, fallbackID)
    local explicit = args and args.archetypeID or nil
    local defaults
    if explicit and Archetypes and Archetypes.Get then
        return Archetypes.Get(explicit).id
    end
    if Archetypes then
        defaults = faction == "hostile" and Archetypes.GetHostileDefaults and Archetypes.GetHostileDefaults()
            or Archetypes.GetCompanionDefaults and Archetypes.GetCompanionDefaults()
        if type(defaults) == "table" and defaults[1] then
            return tostring(defaults[1])
        end
    end
    return fallbackID
end

local function buildSnapshotList()
    local list = {}
    Registry.ForEach(function(record)
        list[#list + 1] = Network.BuildRosterSnapshot(record)
    end)
    return list
end

local function processRecord(record, now)
    local zombie = Registry.GetLiveZombie(record.id)

    Presence.Reconcile(record)
    zombie = Registry.GetLiveZombie(record.id)
    Health.Update(record, zombie, now)
    if Stamina and Stamina.Update then
        Stamina.Update(record, zombie, now)
    end
    if zombie and record.alive ~= false then
        PathService.Pump(record, zombie)
    end

    if record.alive == false then
        if record.lastSyncAt ~= record.presenceRevision then
            Network.BroadcastRemoval(record.id, "death")
            record.lastSyncAt = record.presenceRevision
        end
        return
    end

    if now < (tonumber(record.nextThinkAt) or 0) then
        if zombie and Animation and Animation.SyncLocomotion then
            Animation.SyncLocomotion(zombie, record)
        end
        return
    end

    Behavior.Tick(record, zombie, now)
    record.lastThinkAt = now
    record.nextThinkAt = now + Scheduler.GetCadence(record)

    if (now - (tonumber(record.lastSyncAt) or 0)) >= 500 then
        Network.BroadcastRecord(record, "tick")
        record.lastSyncAt = now
    end

    if zombie and Animation and Animation.SyncLocomotion then
        Animation.SyncLocomotion(zombie, record)
    end
end

function Server.OnTick()
    local now = Core.Now()
    Registry.EnsureLoaded()
    Registry.RefreshLivePositions()
    Spatial.Rebuild()
    Registry.ForEach(function(record)
        processRecord(record, now)
    end)
    if ZombieAggro and ZombieAggro.Pump then
        ZombieAggro.Pump(now)
    end
end

local function handleDebugSpawn(player, args)
    local x = tonumber(args and args.x) or (player and player:getX()) or 0
    local y = tonumber(args and args.y) or (player and player:getY()) or 0
    local z = tonumber(args and args.z) or (player and player:getZ()) or 0

    if args and args.variant == "companion" then
        API.Spawn({
            faction = "companion",
            archetypeID = resolveDebugArchetype(args, "companion", "General"),
            x = x,
            y = y,
            z = z,
            ownerUsername = player and player:getUsername() or nil,
            ownerOnlineID = player and player:getOnlineID() or nil,
            orderSpec = {
                kind = Const.ORDER_FOLLOW,
                ownerUsername = player and player:getUsername() or nil,
                ownerOnlineID = player and player:getOnlineID() or nil,
            },
            forceLive = true,
            weaponMode = "melee",
        })
        return
    end

    if args and args.variant == "hostile_melee" then
        API.Spawn({
            faction = "hostile",
            archetypeID = resolveDebugArchetype(args, "hostile", "Scavenger"),
            x = x,
            y = y,
            z = z,
            orderSpec = { kind = Const.ORDER_HOSTILE_HUNT, x = x, y = y, z = z },
            weaponMode = "melee",
            forceLive = true,
        })
        return
    end

    if args and args.variant == "hostile_ranged" then
        API.Spawn({
            faction = "hostile",
            archetypeID = resolveDebugArchetype(args, "hostile", "Scavenger"),
            x = x,
            y = y,
            z = z,
            orderSpec = { kind = Const.ORDER_HOSTILE_HUNT, x = x, y = y, z = z },
            weaponMode = "ranged",
            forceLive = true,
        })
        return
    end
end

local function onClientCommand(module, command, player, args)
    local snapshots
    if module ~= Const.MODULE then
        return
    end

    if command == Const.CMD_FULL_SYNC_REQUEST then
        snapshots = buildSnapshotList()
        Network.BroadcastFullSync(player, snapshots)
        return
    end

    if command == Const.CMD_REQUEST_CHARACTER and args and args.id then
        Network.SendCharacterPayload(player, Registry.Get(args.id))
        return
    end

    if command ~= Const.CMD_DEBUG then
        return
    end

    if args and args.action == "spawn" then
        handleDebugSpawn(player, args)
        return
    end

    if args and args.action == "force_live" then
        API.DebugCommand(args.id, "force_live", args)
        return
    end

    if args and args.action == "force_abstract" then
        API.DebugCommand(args.id, "force_abstract", args)
        return
    end

    if args and args.action == "heal" then
        API.DebugCommand(args.id, "heal", args)
        return
    end

    if args and args.action == "revive" then
        API.DebugCommand(args.id, "revive", args)
        return
    end

    if args and args.action == "damage" then
        API.DebugCommand(args.id, "damage", args)
        return
    end

    if args and args.action == "set_weapon_mode" then
        API.DebugCommand(args.id, "set_weapon_mode", args)
        return
    end

    if args and args.action == "copy_held_weapon" then
        if player and player.getPrimaryHandItem then
            local primary = player:getPrimaryHandItem()
            if primary and primary.getFullType then
                args.weaponFullType = primary:getFullType()
            end
        end
        args.sourcePlayer = player
        API.DebugCommand(args.id, "copy_held_weapon", args)
        return
    end

    if args and args.action == "copy_player_loadout" then
        args.sourcePlayer = player
        API.DebugCommand(args.id, "copy_player_loadout", args)
        return
    end

    if args and args.action == "toggle_debug" then
        API.DebugCommand(args.id, "toggle_debug", args)
        return
    end

    if args and args.action == "set_order" then
        API.SetOrder(args.id, args.orderSpec)
        return
    end

    if args and args.action == "set_hostility" then
        API.SetHostility(args.id, args.modeSpec)
        return
    end
end

local function onServerStarted()
    Registry.Load()
    Core.LogInfo("PNC server started.")
end

Events.OnTick.Add(Server.OnTick)
Events.OnClientCommand.Add(onClientCommand)
Events.OnServerStarted.Add(onServerStarted)
