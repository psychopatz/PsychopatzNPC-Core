--[[
    PNC NPC Selection
    Owns cursor-near NPC collection and entry building for the shared context
    hub so multiple NPCs can be selected from one world-click.
]]

PNC = PNC or {}
PNC.NPCSelection = PNC.NPCSelection or {}

local Selection = PNC.NPCSelection
local Const = PNC.Const
local Registry = PNC.Registry
local ClientState = PNC.Network.ClientState

local function getWorldSquare(worldObjects)
    local i
    local object
    if type(worldObjects) ~= "table" then
        return nil
    end
    for i = 1, #worldObjects do
        object = worldObjects[i]
        if object and object.getSquare and object:getSquare() then
            return object:getSquare()
        end
    end
    return nil
end

local function buildEntry(zombie, record, snapshot, referenceX, referenceY)
    local x = zombie and zombie.getX and zombie:getX() or snapshot and tonumber(snapshot.x) or record and tonumber(record.x) or 0
    local y = zombie and zombie.getY and zombie:getY() or snapshot and tonumber(snapshot.y) or record and tonumber(record.y) or 0
    local refX = tonumber(referenceX) or x
    local refY = tonumber(referenceY) or y
    return {
        zombie = zombie,
        record = record,
        snapshot = snapshot,
        id = record and record.id or snapshot and snapshot.id or zombie and zombie.getModData and zombie:getModData().PNC_UUID or nil,
        name = record and record.name or snapshot and (snapshot.displayName or snapshot.name) or "PNC NPC",
        archetypeLabel = record and record.archetypeLabel or snapshot and snapshot.archetypeLabel or "NPC",
        x = x,
        y = y,
        z = zombie and zombie.getZ and zombie:getZ() or snapshot and tonumber(snapshot.z) or record and tonumber(record.z) or 0,
        distSq = ((x - refX) * (x - refX)) + ((y - refY) * (y - refY)),
    }
end

function Selection.GetWorldSquare(worldObjects)
    return getWorldSquare(worldObjects)
end

function Selection.CollectNearbyNPCs(player, worldObjects, radius)
    local square = getWorldSquare(worldObjects)
    local entries = {}
    local seen = {}
    local maxDistSq = (tonumber(radius) or 3.0) * (tonumber(radius) or 3.0)
    local referenceX = square and (square:getX() + 0.5) or nil
    local referenceY = square and (square:getY() + 0.5) or nil
    local function pushEntry(zombie, record, snapshot)
        local entry
        local id = record and record.id or snapshot and snapshot.id or zombie and zombie.getModData and zombie:getModData().PNC_UUID or nil
        if not id or seen[id] then
            return
        end
        entry = buildEntry(zombie, record, snapshot, referenceX, referenceY)
        if entry.distSq <= maxDistSq then
            seen[id] = true
            entries[#entries + 1] = entry
        end
    end
    local function scanSquare(scanTarget)
        local movingObjects
        local index
        local zombie
        local record
        local modData
        if not scanTarget then
            return
        end
        movingObjects = scanTarget.getMovingObjects and scanTarget:getMovingObjects() or nil
        if not movingObjects then
            return
        end
        for index = 0, movingObjects:size() - 1 do
            zombie = movingObjects:get(index)
            if zombie and instanceof and instanceof(zombie, "IsoZombie") then
                record = Registry.FindRecordByZombie(zombie)
                modData = zombie.getModData and zombie:getModData() or nil
                if record or (modData and modData.PNC_UUID) then
                    pushEntry(zombie, record or { id = modData.PNC_UUID, name = "PNC NPC", archetypeLabel = "NPC" }, nil)
                end
            end
        end
    end
    local id
    local snapshot
    local dx
    local dy
    local offsetX
    local offsetY

    if not player or not square then
        return entries, square
    end

    scanSquare(square)
    for offsetX = -1, 1 do
        for offsetY = -1, 1 do
            if not (offsetX == 0 and offsetY == 0) then
                scanSquare(getCell() and getCell():getGridSquare(square:getX() + offsetX, square:getY() + offsetY, square:getZ()) or nil)
            end
        end
    end

    for id, snapshot in pairs(ClientState and ClientState.snapshots or {}) do
        if snapshot and snapshot.presenceState == Const.PRESENCE_LIVE and snapshot.alive ~= false and not seen[id] then
            dx = (tonumber(snapshot.x) or 0) - (square:getX() + 0.5)
            dy = (tonumber(snapshot.y) or 0) - (square:getY() + 0.5)
            if ((dx * dx) + (dy * dy)) <= maxDistSq then
                pushEntry(nil, nil, snapshot)
            end
        end
    end

    table.sort(entries, function(left, right)
        if left.distSq ~= right.distSq then
            return left.distSq < right.distSq
        end
        return tostring(left.name) < tostring(right.name)
    end)

    return entries, square
end
