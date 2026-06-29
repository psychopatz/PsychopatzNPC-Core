PNC = PNC or {}
PNC.Core = PNC.Core or {}
PNC.Runtime = PNC.Runtime or {}

local Core = PNC.Core

local function nowMillis()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    if getTimestampMs then
        return getTimestampMs()
    end
    if getGameTime and getGameTime() and getGameTime().getWorldAgeHours then
        return math.floor((tonumber(getGameTime():getWorldAgeHours()) or 0) * 3600000)
    end
    return 0
end

function Core.IsClientOnly()
    return isClient and isClient() and (not isServer or not isServer())
end

function Core.IsAuthority()
    return not Core.IsClientOnly()
end

function Core.Now()
    return nowMillis()
end

function Core.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function Core.Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function Core.DistanceSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return (dx * dx) + (dy * dy)
end

function Core.Distance(x1, y1, x2, y2)
    return math.sqrt(Core.DistanceSq(x1, y1, x2, y2))
end

function Core.TableSize(tbl)
    local count = 0
    if type(tbl) ~= "table" then
        return 0
    end
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Core.ShallowCopy(tbl)
    local copy = {}
    if type(tbl) ~= "table" then
        return copy
    end
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

function Core.DeepCopy(tbl)
    local copy = {}
    local key
    local value
    if type(tbl) ~= "table" then
        return tbl
    end
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            copy[key] = Core.DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function Core.GenerateID(prefix)
    local id = tostring(prefix or "pnc")
        .. "_"
        .. tostring(nowMillis())
        .. "_"
        .. tostring(ZombRand(1000000))
    return id
end

function Core.ResolvePlayerByOnlineID(onlineID)
    local players
    local i
    local player
    if onlineID == nil then
        return nil
    end
    if isServer and isServer() and getOnlinePlayers then
        players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                player = players:get(i)
                if player and player:getOnlineID() == onlineID then
                    return player
                end
            end
        end
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            player = getSpecificPlayer(i)
            if player and player:getOnlineID() == onlineID then
                return player
            end
        end
    end
    return nil
end

function Core.ResolvePlayerByUsername(username)
    local players
    local i
    local player
    if not username then
        return nil
    end
    if isServer and isServer() and getOnlinePlayers then
        players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                player = players:get(i)
                if player and player.getUsername and player:getUsername() == username then
                    return player
                end
            end
        end
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            player = getSpecificPlayer(i)
            if player and player.getUsername and player:getUsername() == username then
                return player
            end
        end
    end
    return nil
end

function Core.ForEachPlayer(callback)
    local players
    local i
    local player
    if type(callback) ~= "function" then
        return
    end
    if isServer and isServer() and getOnlinePlayers then
        players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                player = players:get(i)
                if player then
                    callback(player)
                end
            end
            return
        end
    end
    if getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            player = getSpecificPlayer(i)
            if player then
                callback(player)
            end
        end
    end
end

function Core.GetNearestPlayerPosition(x, y)
    local bestDistSq = math.huge
    local best = nil
    Core.ForEachPlayer(function(player)
        local distSq = Core.DistanceSq(x, y, player:getX(), player:getY())
        if distSq < bestDistSq then
            bestDistSq = distSq
            best = {
                player = player,
                x = player:getX(),
                y = player:getY(),
                z = player:getZ(),
                distSq = distSq,
            }
        end
    end)
    return best
end

function Core.Log(level, message)
    print("[PNC][" .. tostring(level or "INFO") .. "] " .. tostring(message or ""))
end

function Core.LogInfo(message)
    Core.Log("INFO", message)
end

function Core.LogWarn(message)
    Core.Log("WARN", message)
end

function Core.LogDebug(message)
    if PNC.Runtime and PNC.Runtime.debugEnabled then
        Core.Log("DEBUG", message)
    end
end

function Core.IsRecordDebugEnabled(record)
    if record and record.runtime and record.runtime.debug == true then
        return true
    end
    return PNC.Runtime and PNC.Runtime.debugEnabled == true
end

function Core.LogRecordDebug(record, message)
    if Core.IsRecordDebugEnabled(record) then
        Core.Log("DEBUG", message)
    end
end
