PNC = PNC or {}
PNC.SpatialIndex = PNC.SpatialIndex or {}

local Spatial = PNC.SpatialIndex
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry

Spatial.PlayerCells = Spatial.PlayerCells or {}
Spatial.NPCCells = Spatial.NPCCells or {}
Spatial.ZombieCells = Spatial.ZombieCells or {}
Spatial.ZombieByID = Spatial.ZombieByID or {}

local function getCellKey(x, y)
    local size = Const.SPATIAL_CELL_SIZE
    return tostring(math.floor(x / size)) .. ":" .. tostring(math.floor(y / size))
end

local function insertCell(grid, x, y, value)
    local key = getCellKey(x, y)
    local bucket = grid[key]
    if not bucket then
        bucket = {}
        grid[key] = bucket
    end
    bucket[#bucket + 1] = value
end

local function ensureZombieID(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return nil
    end
    modData = zombie:getModData()
    if not modData then
        return nil
    end
    if not modData.PNC_ZombieID or tostring(modData.PNC_ZombieID) == "" then
        modData.PNC_ZombieID = Core.GenerateID("pz")
    end
    return tostring(modData.PNC_ZombieID)
end

local function isManagedNPCBody(zombie)
    local modData
    if not zombie or not zombie.getModData then
        return false
    end
    modData = zombie:getModData()
    return modData and modData.PNC_NPC == true
end

function Spatial.Rebuild()
    local zombieList
    local zombie
    local zombieID
    local i
    Spatial.PlayerCells = {}
    Spatial.NPCCells = {}
    Spatial.ZombieCells = {}
    Spatial.ZombieByID = {}

    Core.ForEachPlayer(function(player)
        insertCell(Spatial.PlayerCells, player:getX(), player:getY(), player)
    end)

    Registry.ForEach(function(record)
        if record.alive ~= false and record.presenceState ~= Const.PRESENCE_CORPSE then
            insertCell(Spatial.NPCCells, record.x, record.y, record)
        end
    end)

    if not getCell then
        return
    end

    zombieList = getCell():getZombieList()
    if not zombieList then
        return
    end

    for i = 0, zombieList:size() - 1 do
        zombie = zombieList:get(i)
        if zombie and (not zombie:isDead()) and (not isManagedNPCBody(zombie)) then
            insertCell(Spatial.ZombieCells, zombie:getX(), zombie:getY(), zombie)
            zombieID = ensureZombieID(zombie)
            if zombieID then
                Spatial.ZombieByID[zombieID] = zombie
            end
        end
    end
end

local function queryGrid(grid, x, y, radius)
    local size = Const.SPATIAL_CELL_SIZE
    local minCellX = math.floor((x - radius) / size)
    local maxCellX = math.floor((x + radius) / size)
    local minCellY = math.floor((y - radius) / size)
    local maxCellY = math.floor((y + radius) / size)
    local results = {}
    local cellX
    local cellY
    local bucket
    local key
    local i

    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            key = tostring(cellX) .. ":" .. tostring(cellY)
            bucket = grid[key]
            if bucket then
                for i = 1, #bucket do
                    results[#results + 1] = bucket[i]
                end
            end
        end
    end
    return results
end

function Spatial.QueryPlayers(x, y, radius)
    return queryGrid(Spatial.PlayerCells, x, y, radius)
end

function Spatial.QueryNPCs(x, y, radius)
    return queryGrid(Spatial.NPCCells, x, y, radius)
end

function Spatial.QueryZombies(x, y, radius)
    return queryGrid(Spatial.ZombieCells, x, y, radius)
end

function Spatial.FindZombieByID(zombieID)
    if not zombieID then
        return nil
    end
    return Spatial.ZombieByID[tostring(zombieID)]
end
