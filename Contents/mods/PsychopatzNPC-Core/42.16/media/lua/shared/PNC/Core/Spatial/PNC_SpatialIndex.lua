PNC = PNC or {}
PNC.SpatialIndex = PNC.SpatialIndex or {}

local Spatial = PNC.SpatialIndex
local Core = PNC.Core
local Const = PNC.Const
local Registry = PNC.Registry

Spatial.PlayerCells = Spatial.PlayerCells or {}
Spatial.NPCCells = Spatial.NPCCells or {}

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

function Spatial.Rebuild()
    Spatial.PlayerCells = {}
    Spatial.NPCCells = {}

    Core.ForEachPlayer(function(player)
        insertCell(Spatial.PlayerCells, player:getX(), player:getY(), player)
    end)

    Registry.ForEach(function(record)
        if record.alive ~= false and record.presenceState ~= Const.PRESENCE_CORPSE then
            insertCell(Spatial.NPCCells, record.x, record.y, record)
        end
    end)
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
