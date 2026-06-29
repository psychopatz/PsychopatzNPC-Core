require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

PNC = PNC or {}
PNC.CharacterWindow = PNC.CharacterWindow or {}

local CharacterWindow = PNC.CharacterWindow
local ClientState = PNC.Network.ClientState
local Tabs = PNC.CharacterWindowTabs

local TAB_ORDER = {
    { id = "Info", label = "Info" },
    { id = "Skills", label = "Skills" },
    { id = "Health", label = "Health" },
    { id = "Protection", label = "Protection" },
    { id = "Temperature", label = "Temperature" },
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

ISPNCCharacterWindow = ISCollapsableWindow:derive("ISPNCCharacterWindow")

function ISPNCCharacterWindow:onTabButton(_, button)
    local tabId = button and button.internal or "Info"
    self.activeTab = tostring(tabId)
    self.scrollY = 0
end

function ISPNCCharacterWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function ISPNCCharacterWindow:createChildren()
    local i
    local tab
    local x = 10
    ISCollapsableWindow.createChildren(self)
    self.tabButtons = {}
    for i = 1, #TAB_ORDER do
        tab = TAB_ORDER[i]
        self.tabButtons[tab.id] = ISButton:new(x, 24, 86, 22, tab.label, self, ISPNCCharacterWindow.onTabButton)
        self.tabButtons[tab.id].internal = tab.id
        self.tabButtons[tab.id]:initialise()
        self.tabButtons[tab.id]:instantiate()
        self.tabButtons[tab.id].borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        self:addChild(self.tabButtons[tab.id])
        x = x + 90
    end
end

function CharacterWindow.Reset()
    local window = CharacterWindow.instance
    if not window then
        return
    end
    if window.removeFromUIManager then
        window:removeFromUIManager()
    end
    CharacterWindow.instance = nil
end

local function onResetLua()
    CharacterWindow.Reset()
end

if Events and Events.OnResetLua then
    Events.OnResetLua.Add(onResetLua)
end

function ISPNCCharacterWindow:setNPC(npcId)
    local summary
    local payload
    self.npcId = npcId
    self.snapshot = ClientState.snapshots and ClientState.snapshots[npcId] or nil
    self.payload = ClientState.characterPayloads and ClientState.characterPayloads[npcId] or nil
    payload = self.payload
    summary = payload and payload.snapshot and payload.snapshot.characterWindow or self.snapshot and self.snapshot.characterWindow or nil
    self.title = "NPC Character"
    if summary and summary.displayName then
        self.title = tostring(summary.displayName) .. " - " .. tostring(summary.archetypeLabel or "NPC")
    elseif self.snapshot and self.snapshot.name then
        self.title = tostring(self.snapshot.name) .. " - NPC"
    end
    if self.setTitle then
        self:setTitle(self.title)
    end
    if PNC.Client and PNC.Client.RequestCharacterPayload then
        PNC.Client.RequestCharacterPayload(npcId)
    end
end

function ISPNCCharacterWindow:updateSnapshot()
    local summary
    if self.npcId and ClientState and ClientState.snapshots then
        self.snapshot = ClientState.snapshots[self.npcId] or self.snapshot
    end
    if self.npcId and ClientState and ClientState.characterPayloads then
        self.payload = ClientState.characterPayloads[self.npcId] or self.payload
    end
    summary = self.payload and self.payload.snapshot and self.payload.snapshot.characterWindow or self.snapshot and self.snapshot.characterWindow or nil
    if summary and summary.displayName and self.setTitle then
        self:setTitle(tostring(summary.displayName) .. " - " .. tostring(summary.archetypeLabel or "NPC"))
    end
end

function ISPNCCharacterWindow:prerender()
    self:updateSnapshot()
    ISCollapsableWindow.prerender(self)
end

function ISPNCCharacterWindow:onMouseWheel(del)
    if self.activeTab ~= "Skills" then
        return false
    end
    self.scrollY = clamp((self.scrollY or 0) - (del * 18), 0, math.max(0, self.maxScroll or 0))
    return true
end

function ISPNCCharacterWindow:render()
    local topY = 58
    local active = self.activeTab or "Info"
    local i
    local tab
    ISCollapsableWindow.render(self)
    for i = 1, #TAB_ORDER do
        tab = TAB_ORDER[i]
        self.tabButtons[tab.id]:setTitle(active == tab.id and ("[" .. tab.label .. "]") or tab.label)
    end
    if active == "Skills" then
        Tabs.RenderSkills(self, self.snapshot or {}, self.payload or {}, topY)
    elseif active == "Health" then
        Tabs.RenderHealth(self, self.snapshot or {}, self.payload or {}, topY)
    elseif active == "Protection" then
        Tabs.RenderProtection(self, self.snapshot or {}, self.payload or {}, topY)
    elseif active == "Temperature" then
        Tabs.RenderTemperature(self, self.snapshot or {}, self.payload or {}, topY)
    else
        Tabs.RenderInfo(self, self.snapshot or {}, self.payload or {}, topY)
    end
end

function ISPNCCharacterWindow:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.activeTab = "Info"
    o.scrollY = 0
    o.maxScroll = 0
    o.resizable = true
    return o
end

function CharacterWindow.Toggle(npcId)
    local window = CharacterWindow.instance
    if not window then
        window = ISPNCCharacterWindow:new(260, 90, 430, 620)
        window:initialise()
        window:instantiate()
        window:addToUIManager()
        CharacterWindow.instance = window
    end
    window:setVisible(true)
    window:setNPC(npcId)
    window:bringToTop()
    return window
end
