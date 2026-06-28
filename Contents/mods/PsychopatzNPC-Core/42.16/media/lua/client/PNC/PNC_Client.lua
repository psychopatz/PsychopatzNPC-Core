--[[
    PNC Client Command Surface
    Owns client-side command requests, server snapshot intake, and the top-level
    world context hook. Focused live-body snapshot application stays in the
    dedicated client presence sync module.
]]

PNC = PNC or {}
PNC.Client = PNC.Client or {}

local Client = PNC.Client
local Const = PNC.Const
local Core = PNC.Core
local Registry = PNC.Registry
local ClientState = PNC.Network.ClientState

local function requestFullSync()
    local player = getSpecificPlayer(0)
    ClientState.lastFullSyncRequestAt = Core.Now()
    if player and sendClientCommand then
        sendClientCommand(player, Const.MODULE, Const.CMD_FULL_SYNC_REQUEST, {})
        return
    end
    if PNC.Registry and PNC.Network and PNC.Network.BuildSnapshot then
        ClientState.snapshots = {}
        PNC.Registry.ForEach(function(record)
            local snapshot = PNC.Network.BuildSnapshot(record)
            ClientState.snapshots[snapshot.id] = snapshot
        end)
        ClientState.lastSyncReceiveAt = Core.Now()
    end
end

Client.RequestFullSync = requestFullSync

function Client.RequestCharacterPayload(npcId)
    local player = getSpecificPlayer(0)
    local payload
    if not npcId then
        return false
    end
    if not sendClientCommand and PNC.API and PNC.API.GetCharacterPayload then
        payload = PNC.API.GetCharacterPayload(npcId)
        if payload then
            ClientState.characterPayloads = ClientState.characterPayloads or {}
            ClientState.characterPayloads[npcId] = payload
            if payload.snapshot and payload.snapshot.id then
                ClientState.snapshots[payload.snapshot.id] = payload.snapshot
            end
            return true
        end
        return false
    end
    if not player or not sendClientCommand then
        return false
    end
    sendClientCommand(player, Const.MODULE, Const.CMD_REQUEST_CHARACTER, { id = npcId })
    return true
end

function Client.HandleServerCommand(command, args)
    local snapshot
    local i
    ClientState.lastSyncReceiveAt = Core.Now()
    if command == Const.CMD_FULL_SYNC then
        ClientState.snapshots = {}
        ClientState.characterPayloads = {}
        if args and args.snapshots then
            for i = 1, #args.snapshots do
                snapshot = args.snapshots[i]
                ClientState.snapshots[snapshot.id] = snapshot
            end
        end
        return
    end

    if command == Const.CMD_SYNC_RECORD then
        snapshot = args and args.snapshot or nil
        if snapshot and snapshot.id then
            ClientState.snapshots[snapshot.id] = snapshot
            if ClientState.characterPayloads and ClientState.characterPayloads[snapshot.id] then
                ClientState.characterPayloads[snapshot.id].snapshot = snapshot
            end
        end
        return
    end

    if command == Const.CMD_CHARACTER_PAYLOAD and args and args.npcId then
        ClientState.characterPayloads = ClientState.characterPayloads or {}
        ClientState.characterPayloads[args.npcId] = args
        if args.snapshot and args.snapshot.id then
            ClientState.snapshots[args.snapshot.id] = args.snapshot
        end
        return
    end

    if command == Const.CMD_REMOVE_RECORD and args and args.id then
        ClientState.snapshots[args.id] = nil
        if ClientState.characterPayloads then
            ClientState.characterPayloads[args.id] = nil
        end
    end
end

function Client.SendDebug(action, payload)
    local player = getSpecificPlayer(0)
    local args = payload or {}
    args.action = action
    if player then
        sendClientCommand(player, Const.MODULE, Const.CMD_DEBUG, args)
    end
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local debugMenu
    local subMenu
    local square
    if test then
        return
    end

    square = PNC.NPCSelection and PNC.NPCSelection.GetWorldSquare and PNC.NPCSelection.GetWorldSquare(worldobjects) or nil
    if square then
        debugMenu = ISContextMenu:getNew(context)
        context:addSubMenu(context:addOption("PNC Debug"), debugMenu)
        debugMenu:addOption("Toggle AI Overlay", nil, function()
            if PNC.Nameplates and PNC.Nameplates.ToggleDebug then
                PNC.Nameplates.ToggleDebug()
            end
        end)

        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(context:addOption("PNC Spawn"), subMenu)
        subMenu:addOption("Spawn Companion", nil, function()
            Client.SendDebug("spawn", { variant = "companion", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
        subMenu:addOption("Spawn Hostile Melee", nil, function()
            Client.SendDebug("spawn", { variant = "hostile_melee", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
        subMenu:addOption("Spawn Hostile Ranged", nil, function()
            Client.SendDebug("spawn", { variant = "hostile_ranged", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
    end
    if PNC.ContextHub and PNC.ContextHub.BuildWorldContext then
        PNC.ContextHub.BuildWorldContext(playerNum, context, worldobjects, test)
    end
end

local function onServerCommand(module, command, args)
    if module == Const.MODULE then
        Client.HandleServerCommand(command, args or {})
    end
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(requestFullSync)
Events.OnCreatePlayer.Add(requestFullSync)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
