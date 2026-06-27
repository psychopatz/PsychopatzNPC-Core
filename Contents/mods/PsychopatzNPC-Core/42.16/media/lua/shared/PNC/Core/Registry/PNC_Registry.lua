PNC = PNC or {}
PNC.Registry = PNC.Registry or {}

local Registry = PNC.Registry
local Core = PNC.Core
local Const = PNC.Const

Registry.Data = Registry.Data or {}
Registry.LiveByID = Registry.LiveByID or {}
Registry.Loaded = Registry.Loaded or false

local function getStore()
    local data = ModData.getOrCreate(Const.MODDATA_KEY)
    if not data.NPCs then
        data.NPCs = {}
    end
    return data
end

function Registry.Load()
    local store
    if not Core.IsAuthority() then
        return
    end
    store = getStore()
    Registry.Data = store.NPCs
    Registry.LiveByID = {}
    Registry.Loaded = true
    Core.LogInfo("Registry loaded with " .. tostring(Core.TableSize(Registry.Data)) .. " NPC records.")
end

function Registry.EnsureLoaded()
    if not Registry.Loaded and Core.IsAuthority() then
        Registry.Load()
    end
end

function Registry.Save()
    local store
    if not Core.IsAuthority() then
        return
    end
    Registry.EnsureLoaded()
    store = getStore()
    store.NPCs = Registry.Data
    if ModData and ModData.transmit then
        ModData.transmit(Const.MODDATA_KEY)
    end
    if GlobalModData and GlobalModData.save then
        GlobalModData.save()
    end
end

function Registry.ForEach(callback)
    local id
    local record
    Registry.EnsureLoaded()
    if type(callback) ~= "function" then
        return
    end
    for id, record in pairs(Registry.Data) do
        callback(record, id)
    end
end

function Registry.ForEachLive(callback)
    local id
    local zombie
    local record
    if type(callback) ~= "function" then
        return
    end
    for id, zombie in pairs(Registry.LiveByID) do
        record = Registry.Data[id]
        if record and zombie then
            callback(record, zombie, id)
        end
    end
end

function Registry.AddRecord(record)
    Registry.EnsureLoaded()
    Registry.Data[record.id] = record
    Registry.Save()
end

function Registry.RemoveRecord(id)
    Registry.EnsureLoaded()
    Registry.LiveByID[id] = nil
    Registry.Data[id] = nil
    Registry.Save()
end

function Registry.Get(id)
    Registry.EnsureLoaded()
    return Registry.Data[id]
end

function Registry.GetLiveZombie(id)
    return Registry.LiveByID[id]
end

function Registry.RegisterLiveZombie(record, zombie)
    local modData
    if not record or not zombie then
        return
    end
    Registry.LiveByID[record.id] = zombie
    modData = zombie:getModData()
    modData.PNC_UUID = record.id
    modData.PNC_NPC = true
    record.liveBodyInstanceID = zombie.getPersistentOutfitID and zombie:getPersistentOutfitID() or nil
    record.presenceRevision = (tonumber(record.presenceRevision) or 0) + 1
end

function Registry.UnregisterLiveZombie(id)
    local record = Registry.Get(id)
    Registry.LiveByID[id] = nil
    if record then
        record.liveBodyInstanceID = nil
        record.presenceRevision = (tonumber(record.presenceRevision) or 0) + 1
    end
end

function Registry.FindRecordByZombie(zombie)
    local modData
    local uuid
    if not zombie then
        return nil
    end
    modData = zombie:getModData()
    uuid = modData and modData.PNC_UUID or nil
    if not uuid then
        return nil
    end
    return Registry.Get(uuid)
end

function Registry.RefreshLivePositions()
    local id
    local zombie
    local record
    for id, zombie in pairs(Registry.LiveByID) do
        record = Registry.Data[id]
        if record and zombie then
            if zombie.isDead and zombie:isDead() then
                Registry.LiveByID[id] = nil
            else
                record.x = zombie:getX()
                record.y = zombie:getY()
                record.z = zombie:getZ()
            end
        end
    end
end

local function onInitGlobalModData()
    Registry.Load()
end

local function onSave()
    Registry.Save()
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
Events.OnSave.Add(onSave)
