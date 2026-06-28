--[[
    PNC Client Presence Sync
    Owns multiplayer-side live NPC body reconciliation for nearby replicated
    zombie actors. It applies compact server snapshots to client visuals
    without creating client authority or re-running server gameplay logic.
]]

PNC = PNC or {}
PNC.ClientPresenceSync = PNC.ClientPresenceSync or {}

local Sync = PNC.ClientPresenceSync
local Core = PNC.Core
local Const = PNC.Const
local Animation = PNC.Animation
local Client = PNC.Client
local ClientState = PNC.Network.ClientState

Sync.BodyByID = Sync.BodyByID or {}
Sync.lastBodyScanAt = Sync.lastBodyScanAt or 0

local function buildRecordView(snapshot)
    return {
        activeBehavior = snapshot and snapshot.activeBehavior or snapshot and snapshot.aiState or "Idle",
        activeJob = snapshot and snapshot.activeJob or snapshot and snapshot.aiState or "Idle",
        orderSpec = {
            kind = snapshot and snapshot.orderKind or "none",
        },
        presenceState = snapshot and snapshot.presenceState or Const.PRESENCE_ABSTRACT,
        weaponMode = snapshot and snapshot.weaponMode or "melee",
    }
end

local function applyIdentityVars(zombie, snapshot)
    if not zombie or not zombie.setVariable then
        return
    end
    zombie:setVariable("PNCActor", true)
    zombie:setVariable("PNCLive", snapshot and snapshot.presenceState == Const.PRESENCE_LIVE)
    if zombie.setFemaleEtc then
        zombie:setFemaleEtc(snapshot and snapshot.isFemale == true)
    end
end

local function refreshBodyMap(now)
    local zombieList
    local body
    local modData
    local i
    if not getCell or now < ((tonumber(Sync.lastBodyScanAt) or 0) + 750) then
        return
    end
    Sync.lastBodyScanAt = now
    Sync.BodyByID = {}
    zombieList = getCell():getZombieList()
    if not zombieList then
        return
    end
    for i = 0, zombieList:size() - 1 do
        body = zombieList:get(i)
        modData = body and body.getModData and body:getModData() or nil
        if modData and modData.PNC_UUID and modData.PNC_NPC == true then
            Sync.BodyByID[tostring(modData.PNC_UUID)] = body
        end
    end
end

local function applySnapshotToBody(snapshot, zombie)
    local visualState = snapshot and snapshot.visualState or {}
    local modData = zombie and zombie.getModData and zombie:getModData() or nil
    local attackKey
    local desiredAnim
    local recordView
    if not snapshot or not zombie or (zombie.isDead and zombie:isDead()) then
        return
    end

    recordView = buildRecordView(snapshot)
    applyIdentityVars(zombie, snapshot)

    if snapshot.healthState == "incapacitated" then
        if Animation and Animation.ApplyDowned then
            Animation.ApplyDowned(zombie, recordView, visualState.anim == "Crawl")
        end
    elseif Animation and Animation.ClearDowned then
        Animation.ClearDowned(zombie)
    end

    attackKey = visualState.attackActive and visualState.attackAnim
        and (tostring(visualState.attackAnim) .. ":" .. tostring(visualState.attackFinishAt or 0))
        or nil
    if attackKey and modData and modData.PNC_ClientAttackKey ~= attackKey then
        Animation.PlayBump(zombie, recordView, visualState.attackAnim)
        modData.PNC_ClientAttackKey = attackKey
        return
    end
    if modData and not attackKey then
        modData.PNC_ClientAttackKey = nil
    end
    if attackKey then
        return
    end

    desiredAnim = visualState.anim or "Idle"
    if Animation and Animation.Apply then
        Animation.Apply(zombie, recordView, desiredAnim)
    end
    if Animation and Animation.SyncLocomotion then
        Animation.SyncLocomotion(zombie)
    end
end

local function requestSyncIfStale(now)
    local player = getSpecificPlayer(0)
    local lastRequestAt = tonumber(ClientState.lastFullSyncRequestAt or 0) or 0
    local lastReceiveAt = tonumber(ClientState.lastSyncReceiveAt or 0) or 0
    local hasSnapshots = false
    local id
    if not player or not sendClientCommand or not Client or not Client.RequestFullSync then
        return
    end
    for id, _ in pairs(ClientState and ClientState.snapshots or {}) do
        hasSnapshots = true
        break
    end
    if hasSnapshots then
        return
    end
    if lastReceiveAt > 0 and (now - lastReceiveAt) < 6000 then
        return
    end
    if (now - lastRequestAt) < 4000 then
        return
    end
    Client.RequestFullSync()
end

function Sync.OnTick()
    local now = Core.Now()
    local id
    local snapshot
    local body
    requestSyncIfStale(now)
    refreshBodyMap(now)
    for id, snapshot in pairs(ClientState and ClientState.snapshots or {}) do
        if snapshot and snapshot.presenceState == Const.PRESENCE_LIVE and snapshot.alive ~= false then
            body = Sync.BodyByID[id]
            if body then
                applySnapshotToBody(snapshot, body)
            end
        end
    end
end

Events.OnTick.Add(Sync.OnTick)
