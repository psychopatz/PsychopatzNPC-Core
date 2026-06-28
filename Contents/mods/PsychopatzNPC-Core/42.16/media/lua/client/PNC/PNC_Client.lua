PNC = PNC or {}
PNC.Client = PNC.Client or {}

local Client = PNC.Client
local Const = PNC.Const
local Core = PNC.Core
local Registry = PNC.Registry
local ClientState = PNC.Network.ClientState

local function requestFullSync()
    local player = getSpecificPlayer(0)
    if player and sendClientCommand then
        sendClientCommand(player, Const.MODULE, Const.CMD_FULL_SYNC_REQUEST, {})
    end
end

local function getWorldSquare(worldobjects)
    local i
    local object
    if type(worldobjects) ~= "table" then
        return nil
    end
    for i = 1, #worldobjects do
        object = worldobjects[i]
        if object and object.getSquare then
            return object:getSquare()
        end
    end
    return nil
end

local function getTargetNPC(worldobjects)
    local i
    local object
    local record
    if type(worldobjects) ~= "table" then
        return nil, nil
    end
    for i = 1, #worldobjects do
        object = worldobjects[i]
        if object and instanceof and instanceof(object, "IsoZombie") then
            record = Registry.FindRecordByZombie(object)
            if record or (object.getModData and object:getModData().PNC_UUID) then
                return object, record or { id = object:getModData().PNC_UUID, name = "PNC NPC" }
            end
        end
    end
    return nil, nil
end

local function getTargetNPCNearSquare(square)
    local cell
    local zombieList
    local bestZombie
    local bestRecord
    local bestDistSq
    local i
    local zombie
    local modData
    local record
    local dx
    local dy
    local distSq

    if not square or not getCell then
        return nil, nil
    end

    cell = getCell()
    zombieList = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombieList then
        return nil, nil
    end

    bestDistSq = 2.25
    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and zombie.getModData then
            modData = zombie:getModData()
            if modData and modData.PNC_UUID then
                record = Registry.FindRecordByZombie(zombie) or { id = modData.PNC_UUID, name = "PNC NPC" }
                dx = zombie:getX() - (square:getX() + 0.5)
                dy = zombie:getY() - (square:getY() + 0.5)
                distSq = (dx * dx) + (dy * dy)
                if distSq <= bestDistSq then
                    bestDistSq = distSq
                    bestZombie = zombie
                    bestRecord = record
                end
            end
        end
    end

    return bestZombie, bestRecord
end

local function getSnapshotNPCNearSquare(square)
    local bestSnapshot
    local bestDistSq
    local id
    local snapshot
    local dx
    local dy
    local distSq

    if not square or not ClientState or not ClientState.snapshots then
        return nil
    end

    bestDistSq = 2.25
    for id, snapshot in pairs(ClientState.snapshots) do
        if snapshot and snapshot.presenceState == Const.PRESENCE_LIVE and snapshot.alive ~= false then
            dx = (tonumber(snapshot.x) or 0) - (square:getX() + 0.5)
            dy = (tonumber(snapshot.y) or 0) - (square:getY() + 0.5)
            distSq = (dx * dx) + (dy * dy)
            if distSq <= bestDistSq then
                bestDistSq = distSq
                bestSnapshot = {
                    id = snapshot.id or id,
                    name = snapshot.name or "PNC NPC",
                    x = snapshot.x,
                    y = snapshot.y,
                    z = snapshot.z,
                }
            end
        end
    end

    return bestSnapshot
end

function Client.HandleServerCommand(command, args)
    local snapshot
    local i
    if command == Const.CMD_FULL_SYNC then
        ClientState.snapshots = {}
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
        end
        return
    end

    if command == Const.CMD_REMOVE_RECORD and args and args.id then
        ClientState.snapshots[args.id] = nil
    end
end

local function sendDebug(action, payload)
    local player = getSpecificPlayer(0)
    local args = payload or {}
    args.action = action
    if player then
        sendClientCommand(player, Const.MODULE, Const.CMD_DEBUG, args)
    end
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local square
    local zombie
    local record
    local subMenu
    local orderMenu
    local weaponMenu
    local player
    local heldItem
    local actionSquare
    local debugMenu
    local snapshot
    local snapshotText
    if test then
        return
    end

    square = getWorldSquare(worldobjects)
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
            sendDebug("spawn", { variant = "companion", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
        subMenu:addOption("Spawn Hostile Melee", nil, function()
            sendDebug("spawn", { variant = "hostile_melee", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
        subMenu:addOption("Spawn Hostile Ranged", nil, function()
            sendDebug("spawn", { variant = "hostile_ranged", x = square:getX(), y = square:getY(), z = square:getZ() })
        end)
    end

    zombie, record = getTargetNPC(worldobjects)
    if (not zombie or not record) and square then
        zombie, record = getTargetNPCNearSquare(square)
    end
    if (not record) and square then
        record = getSnapshotNPCNearSquare(square)
    end
    if record and record.id then
        player = getSpecificPlayer(playerNum)
        heldItem = player and player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
        actionSquare = zombie and zombie.getSquare and zombie:getSquare() or square
        subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(context:addOption("PNC NPC"), subMenu)
        subMenu:addOption("Force Live", nil, function()
            sendDebug("force_live", { id = record.id })
        end)
        subMenu:addOption("Force Abstract", nil, function()
            sendDebug("force_abstract", { id = record.id })
        end)
        subMenu:addOption("Heal", nil, function()
            sendDebug("heal", { id = record.id })
        end)
        subMenu:addOption("Damage 25", nil, function()
            sendDebug("damage", { id = record.id, amount = 25 })
        end)
        subMenu:addOption("Dump Snapshot", nil, function()
            snapshot = ClientState.snapshots and ClientState.snapshots[record.id] or nil
            snapshotText = PNC.Nameplates and PNC.Nameplates.DebugDescribeSnapshot
                and PNC.Nameplates.DebugDescribeSnapshot(snapshot)
                or tostring(snapshot and snapshot.aiState or "No snapshot")
            print("[PNC] " .. snapshotText)
            if player and HaloTextHelper and HaloTextHelper.addText then
                HaloTextHelper.addText(player, "PNC snapshot printed to console")
            end
        end)
        subMenu:addOption("Toggle Combat Debug", nil, function()
            sendDebug("toggle_debug", { id = record.id })
        end)
        subMenu:addOption("View Skills", nil, function()
            if PNC.SkillsWindow and PNC.SkillsWindow.Toggle then
                PNC.SkillsWindow.Toggle(record.id)
            end
        end)
        snapshot = ClientState.snapshots and ClientState.snapshots[record.id] or nil
        if snapshot and snapshot.healthState == "incapacitated" and snapshot.canRevive == true then
            subMenu:addOption("Revive", nil, function()
                sendDebug("revive", { id = record.id })
            end)
        end

        orderMenu = ISContextMenu:getNew(context)
        subMenu:addSubMenu(subMenu:addOption("Orders"), orderMenu)
        orderMenu:addOption("Follow Me", nil, function()
            sendDebug("set_order", {
                id = record.id,
                orderSpec = {
                    kind = Const.ORDER_FOLLOW,
                    ownerUsername = player and player:getUsername() or nil,
                    ownerOnlineID = player and player:getOnlineID() or nil,
                },
            })
        end)
        orderMenu:addOption("Guard Here", nil, function()
            local sq = actionSquare
            sendDebug("set_order", {
                id = record.id,
                orderSpec = { kind = Const.ORDER_GUARD, x = sq:getX(), y = sq:getY(), z = sq:getZ() },
            })
        end)
        orderMenu:addOption("Patrol Nearby", nil, function()
            local sq = actionSquare
            sendDebug("set_order", {
                id = record.id,
                orderSpec = {
                    kind = Const.ORDER_PATROL,
                    points = {
                        { x = sq:getX(), y = sq:getY(), z = sq:getZ() },
                        { x = sq:getX() + 4, y = sq:getY(), z = sq:getZ() },
                    },
                },
            })
        end)
        orderMenu:addOption("Hostile Hunt", nil, function()
            local sq = actionSquare
            sendDebug("set_order", {
                id = record.id,
                orderSpec = { kind = Const.ORDER_HOSTILE_HUNT, x = sq:getX(), y = sq:getY(), z = sq:getZ() },
            })
            sendDebug("set_hostility", {
                id = record.id,
                modeSpec = { mode = "hostile_any_player", attackPlayers = true, attackNPCs = true },
            })
        end)
        orderMenu:addOption("Hostile Roam", nil, function()
            local sq = actionSquare
            sendDebug("set_order", {
                id = record.id,
                orderSpec = { kind = Const.ORDER_HOSTILE_ROAM, x = sq:getX(), y = sq:getY(), z = sq:getZ() },
            })
            sendDebug("set_hostility", {
                id = record.id,
                modeSpec = { mode = "hostile_any_player", attackPlayers = true, attackNPCs = true },
            })
        end)

        weaponMenu = ISContextMenu:getNew(context)
        subMenu:addSubMenu(subMenu:addOption("Combat"), weaponMenu)
        weaponMenu:addOption("Set Melee", nil, function()
            sendDebug("set_weapon_mode", { id = record.id, weaponMode = "melee" })
        end)
        weaponMenu:addOption("Set Ranged", nil, function()
            sendDebug("set_weapon_mode", { id = record.id, weaponMode = "ranged" })
        end)
        weaponMenu:addOption("Set Mixed", nil, function()
            sendDebug("set_weapon_mode", { id = record.id, weaponMode = "mixed" })
        end)
        if heldItem and heldItem.getFullType then
            weaponMenu:addOption("Use My Held Weapon", nil, function()
                print("[PNC] Requesting held weapon copy for " .. tostring(record.id) .. " fullType=" .. tostring(heldItem:getFullType()))
                sendDebug("copy_held_weapon", { id = record.id, weaponFullType = heldItem:getFullType() })
            end)
        end
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
