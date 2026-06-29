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
local Visuals = PNC.Visuals
local Equipment = PNC.Equipment

Sync.BodyByID = Sync.BodyByID or {}
Sync.BodyByInstanceID = Sync.BodyByInstanceID or {}
Sync.lastBodyScanAt = Sync.lastBodyScanAt or 0

local function isWorldReady()
    return (not isIngameState) or isIngameState()
end

local function buildRecordView(snapshot)
    local visualState = snapshot and snapshot.visualState or {}
    return {
        activeBehavior = snapshot and snapshot.activeBehavior or snapshot and snapshot.aiState or "Idle",
        activeJob = snapshot and snapshot.activeJob or snapshot and snapshot.aiState or "Idle",
        orderSpec = {
            kind = snapshot and snapshot.orderKind or "none",
        },
        presenceState = snapshot and snapshot.presenceState or Const.PRESENCE_ABSTRACT,
        weaponMode = snapshot and snapshot.weaponMode or "melee",
        visualProfile = snapshot and snapshot.visualProfile or nil,
        isFemale = snapshot and snapshot.isFemale == true or false,
        identitySeed = snapshot and snapshot.identitySeed or 1,
        archetypeID = snapshot and snapshot.archetypeID or nil,
        archetypeLabel = snapshot and snapshot.archetypeLabel or nil,
        outfit = snapshot and snapshot.appearance and snapshot.appearance.outfit or nil,
        identity = snapshot and snapshot.identity or nil,
        equipment = {
            primaryFullType = snapshot and snapshot.equipmentSummary and snapshot.equipmentSummary.primaryFullType or nil,
            secondaryFullType = snapshot and snapshot.equipmentSummary and snapshot.equipmentSummary.secondaryFullType or nil,
            worn = snapshot and snapshot.equipmentSummary and snapshot.equipmentSummary.worn or {},
            attached = snapshot and snapshot.equipmentSummary and snapshot.equipmentSummary.attached or {},
        },
        runtime = {
            pathing = {
                animSpeed = tonumber(visualState.animSpeed) or 1.0,
                mode = visualState.mode or "walk",
                resolvedMode = visualState.mode or "walk",
            },
        },
    }
end

local function stableTableSignature(tbl)
    local keys = {}
    local i = 0
    local key
    if type(tbl) ~= "table" then
        return ""
    end
    for key, _ in pairs(tbl) do
        i = i + 1
        keys[i] = tostring(key)
    end
    table.sort(keys)
    for i = 1, #keys do
        keys[i] = keys[i] .. "=" .. tostring(tbl[keys[i]] or "")
    end
    return table.concat(keys, ";")
end

local function buildVisualKey(snapshot)
    local appearance = snapshot and snapshot.appearance or {}
    local equipment = snapshot and snapshot.equipmentSummary or {}
    return table.concat({
        tostring(snapshot and snapshot.presenceRevision or 0),
        tostring(snapshot and snapshot.visualProfile or ""),
        tostring(snapshot and snapshot.isFemale == true),
        tostring(appearance.outfit or ""),
        tostring(appearance.skinTexture or ""),
        tostring(appearance.hairModel or ""),
        tostring(appearance.beardModel or ""),
        tostring(equipment.primaryFullType or ""),
        tostring(equipment.secondaryFullType or ""),
        stableTableSignature(equipment.worn),
        stableTableSignature(equipment.attached),
    }, "|")
end

local function buildMotionKey(snapshot)
    local visualState = snapshot and snapshot.visualState or {}
    return table.concat({
        tostring(snapshot and snapshot.presenceRevision or 0),
        tostring(snapshot and snapshot.healthState or "normal"),
        tostring(visualState.anim or "Idle"),
        tostring(visualState.walkType or ""),
        tostring(visualState.mode or ""),
        tostring(visualState.moving == true),
        tostring(visualState.attackActive == true),
        tostring(visualState.attackAnim or ""),
        tostring(visualState.attackFinishAt or 0),
        tostring(tonumber(visualState.animSpeed) or 1.0),
        tostring(visualState.specialActive == true),
        tostring(visualState.specialAnim or ""),
        tostring(visualState.specialFinishAt or 0),
    }, "|")
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
    Sync.BodyByInstanceID = {}
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
        if body and body.getPersistentOutfitID then
            Sync.BodyByInstanceID[tostring(body:getPersistentOutfitID() or "")] = body
        end
    end
end

local function applySnapshotToBody(snapshot, zombie)
    local visualState = snapshot and snapshot.visualState or {}
    local modData = zombie and zombie.getModData and zombie:getModData() or nil
    local attackKey
    local specialKey
    local desiredAnim
    local recordView
    local visualKey
    local motionKey
    if not snapshot or not zombie or (zombie.isDead and zombie:isDead()) then
        return
    end

    recordView = buildRecordView(snapshot)
    applyIdentityVars(zombie, snapshot)

    visualKey = buildVisualKey(snapshot)
    if modData and modData.PNC_ClientVisualKey ~= visualKey then
        if Animation and Animation.ApplyLiveSetup then
            Animation.ApplyLiveSetup(zombie, recordView)
        end
        if Visuals and Visuals.ApplyResolvedAppearance then
            Visuals.ApplyResolvedAppearance(zombie, snapshot.appearance or {}, snapshot.isFemale == true)
        end
        if Equipment and Equipment.Apply then
            Equipment.Apply(zombie, recordView)
        end
        modData.PNC_ClientVisualKey = visualKey
    end

    motionKey = buildMotionKey(snapshot)

    if snapshot.healthState == "incapacitated" then
        if Animation and Animation.ApplyDowned and (not modData or modData.PNC_ClientMotionKey ~= motionKey) then
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
        modData.PNC_ClientMotionKey = motionKey
        return
    end
    if modData and not attackKey then
        modData.PNC_ClientAttackKey = nil
    end
    if attackKey then
        return
    end

    specialKey = visualState.specialActive and visualState.specialAnim
        and (tostring(visualState.specialAnim) .. ":" .. tostring(visualState.specialFinishAt or 0))
        or nil
    if specialKey and modData and modData.PNC_ClientSpecialKey ~= specialKey then
        Animation.PlayBump(zombie, recordView, visualState.specialAnim)
        modData.PNC_ClientSpecialKey = specialKey
        modData.PNC_ClientMotionKey = motionKey
        return
    end
    if modData and not specialKey then
        modData.PNC_ClientSpecialKey = nil
    end
    if specialKey then
        return
    end

    desiredAnim = visualState.anim or "Idle"
    if Animation and Animation.Apply and (not modData or modData.PNC_ClientMotionKey ~= motionKey) then
        Animation.Apply(zombie, recordView, desiredAnim)
        if Animation and Animation.SyncLocomotion then
            Animation.SyncLocomotion(zombie)
        end
        if modData then
            modData.PNC_ClientMotionKey = motionKey
        end
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
    if not isWorldReady() then
        return
    end
    requestSyncIfStale(now)
    refreshBodyMap(now)
    for id, snapshot in pairs(ClientState and ClientState.snapshots or {}) do
        if snapshot and snapshot.presenceState == Const.PRESENCE_LIVE and snapshot.alive ~= false then
            body = Sync.BodyByID[id]
                or Sync.BodyByInstanceID[tostring(snapshot.liveBodyInstanceID or "")]
            if body then
                applySnapshotToBody(snapshot, body)
            end
        end
    end
end

local function onResetLua()
    Sync.BodyByID = {}
    Sync.BodyByInstanceID = {}
    Sync.lastBodyScanAt = 0
end

if Events and Events.OnTick then
    Events.OnTick.Add(Sync.OnTick)
end

if Events and Events.OnResetLua then
    Events.OnResetLua.Add(onResetLua)
end
