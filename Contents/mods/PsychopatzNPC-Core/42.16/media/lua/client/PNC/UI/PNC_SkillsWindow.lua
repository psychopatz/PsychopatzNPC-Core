require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

PNC = PNC or {}
PNC.SkillsWindow = PNC.SkillsWindow or {}

local SkillsWindow = PNC.SkillsWindow
local Catalog = PNC.SkillCatalog
local ClientState = PNC.Network.ClientState

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

ISPNCSkillsWindow = ISCollapsableWindow:derive("ISPNCSkillsWindow")

function ISPNCSkillsWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function ISPNCSkillsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.infoButton = ISButton:new(10, 24, 64, 22, "Info", self, function()
        self.activeTab = "info"
    end)
    self.infoButton:initialise()
    self.infoButton:instantiate()
    self.infoButton.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self:addChild(self.infoButton)

    self.skillsButton = ISButton:new(80, 24, 64, 22, "Skills", self, function()
        self.activeTab = "skills"
    end)
    self.skillsButton:initialise()
    self.skillsButton:instantiate()
    self.skillsButton.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self:addChild(self.skillsButton)
end

function ISPNCSkillsWindow:setNPC(npcId)
    self.npcId = npcId
    self.snapshot = ClientState.snapshots and ClientState.snapshots[npcId] or nil
    self.title = "NPC Profile"
    if self.snapshot and self.snapshot.name then
        self.title = tostring(self.snapshot.name) .. " Profile"
    end
    if self.setTitle then
        self:setTitle(self.title)
    end
end

function ISPNCSkillsWindow:updateSnapshot()
    if self.npcId and ClientState and ClientState.snapshots then
        self.snapshot = ClientState.snapshots[self.npcId] or self.snapshot
    end
end

function ISPNCSkillsWindow:prerender()
    self:updateSnapshot()
    ISCollapsableWindow.prerender(self)
end

function ISPNCSkillsWindow:onMouseWheel(del)
    if self.activeTab ~= "skills" then
        return false
    end
    self.scrollY = clamp((self.scrollY or 0) - (del * 18), 0, math.max(0, self.maxScroll or 0))
    return true
end

function ISPNCSkillsWindow:drawInfoTab()
    local snapshot = self.snapshot or {}
    local lines = {
        "Name: " .. tostring(snapshot.name or "Unknown"),
        "Faction: " .. tostring(snapshot.faction or "Unknown"),
        "State: " .. tostring(snapshot.aiState or snapshot.healthState or "Idle"),
        "Health: " .. tostring(snapshot.hpCurrent or 0) .. "/" .. tostring(snapshot.hpMax or 0),
        "Stamina: " .. tostring(math.floor((tonumber(snapshot.staminaCurrent) or 0) + 0.5))
            .. "/" .. tostring(math.floor((tonumber(snapshot.staminaMax) or 0) + 0.5))
            .. " (" .. tostring(snapshot.staminaState or "fresh") .. ")",
        "Weapon: " .. tostring(snapshot.weaponFullType or "Bare hands"),
        "Mode: " .. tostring(snapshot.combatModeResolved or snapshot.weaponMode or "melee"),
        "Identity Seed: " .. tostring(snapshot.identitySeed or 1),
        "Learns Skills: " .. ((snapshot.recruited == true) and "Yes" or "No"),
    }
    local i
    local y = 58
    for i = 1, #lines do
        self:drawText(lines[i], 16, y, 1, 1, 1, 1, UIFont.Small)
        y = y + 18
    end
end

function ISPNCSkillsWindow:drawSkillRow(skill, level, y)
    local i
    local boxX = self.width - 150
    local clampedLevel = clamp(math.floor(tonumber(level) or 0), 0, 10)
    self:drawText(skill.display, 28, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
    for i = 0, 9 do
        self:drawRectBorder(boxX + (i * 12), y + 2, 10, 10, 0.9, 0.6, 0.6, 0.6)
        if i < clampedLevel then
            self:drawRect(boxX + (i * 12) + 1, y + 3, 8, 8, 0.9, 0.82, 0.82, 0.82)
        end
    end
end

function ISPNCSkillsWindow:drawSkillsTab()
    local groups = Catalog.GetGroups()
    local snapshot = self.snapshot or {}
    local skillLevels = snapshot.skillLevels or {}
    local i
    local j
    local group
    local skill
    local y = 56 - (self.scrollY or 0)

    for i = 1, #groups do
        group = groups[i]
        self:drawRect(10, y, self.width - 20, 22, 0.22, 0.1, 0.1, 0.1)
        self:drawText(group.display, 16, y + 4, 1, 1, 1, 1, UIFont.Medium)
        y = y + 28
        for j = 1, #(group.skills or {}) do
            skill = group.skills[j]
            self:drawSkillRow(skill, skillLevels[skill.id] or 0, y)
            y = y + 16
        end
        y = y + 12
    end

    self.maxScroll = math.max(0, y - (self.height - 32))
    self.scrollY = clamp(self.scrollY or 0, 0, self.maxScroll)
end

function ISPNCSkillsWindow:render()
    ISCollapsableWindow.render(self)
    self.infoButton:setTitle(self.activeTab == "info" and "[Info]" or "Info")
    self.skillsButton:setTitle(self.activeTab == "skills" and "[Skills]" or "Skills")
    if self.activeTab == "skills" then
        self:drawSkillsTab()
    else
        self:drawInfoTab()
    end
end

function ISPNCSkillsWindow:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.activeTab = "skills"
    o.scrollY = 0
    o.maxScroll = 0
    o.resizable = true
    return o
end

function SkillsWindow.Toggle(npcId)
    local window = SkillsWindow.instance
    if not window then
        window = ISPNCSkillsWindow:new(280, 120, 360, 600)
        window:initialise()
        window:instantiate()
        window:addToUIManager()
        SkillsWindow.instance = window
    end
    window:setVisible(true)
    window:setNPC(npcId)
    window:bringToTop()
    return window
end
