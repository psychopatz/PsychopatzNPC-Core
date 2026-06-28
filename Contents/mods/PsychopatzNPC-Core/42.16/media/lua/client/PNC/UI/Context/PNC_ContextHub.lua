PNC = PNC or {}
PNC.ContextHub = PNC.ContextHub or {}

local ContextHub = PNC.ContextHub
local Selection = PNC.NPCSelection

ContextHub.Providers = ContextHub.Providers or {}
ContextHub.ProviderOrder = ContextHub.ProviderOrder or {}

local function appendUnique(list, value)
    local i
    for i = 1, #list do
        if list[i] == value then
            return
        end
    end
    list[#list + 1] = value
end

function ContextHub.RegisterProvider(provider)
    if type(provider) ~= "table" or not provider.id or type(provider.addOptions) ~= "function" then
        return false
    end
    ContextHub.Providers[tostring(provider.id)] = provider
    appendUnique(ContextHub.ProviderOrder, tostring(provider.id))
    return true
end

local function formatEntryLabel(entry)
    local distance = math.sqrt(tonumber(entry and entry.distSq) or 0)
    return tostring(entry and entry.name or "PNC NPC")
        .. " ["
        .. tostring(entry and entry.archetypeLabel or "NPC")
        .. "] "
        .. string.format("(%.1f)", distance)
end

function ContextHub.AddEntryOptions(menu, player, entry, contextData)
    local subMenu = ISContextMenu:getNew(menu)
    local i
    local provider
    menu:addSubMenu(menu:addOption(formatEntryLabel(entry)), subMenu)
    for i = 1, #ContextHub.ProviderOrder do
        provider = ContextHub.Providers[ContextHub.ProviderOrder[i]]
        if provider and (provider.isEnabled == nil or provider.isEnabled(entry, player, contextData) ~= false) then
            provider.addOptions(subMenu, entry, player, contextData)
        end
    end
end

function ContextHub.BuildWorldContext(playerNum, context, worldObjects, test)
    local player
    local entries
    local square
    local rootMenu
    local contextData
    local i
    if test then
        return
    end
    player = getSpecificPlayer(playerNum)
    if not player or not context then
        return
    end
    entries, square = Selection.CollectNearbyNPCs(player, worldObjects, 3.0)
    contextData = {
        playerNum = playerNum,
        worldObjects = worldObjects,
        square = square,
    }
    if #entries <= 0 then
        return
    end
    if #entries == 1 then
        rootMenu = ISContextMenu:getNew(context)
        context:addSubMenu(context:addOption("PNC NPC"), rootMenu)
        for i = 1, #ContextHub.ProviderOrder do
            local provider = ContextHub.Providers[ContextHub.ProviderOrder[i]]
            if provider and (provider.isEnabled == nil or provider.isEnabled(entries[1], player, contextData) ~= false) then
                provider.addOptions(rootMenu, entries[1], player, contextData)
            end
        end
        return
    end
    rootMenu = ISContextMenu:getNew(context)
    context:addSubMenu(context:addOption("PNC NPCs"), rootMenu)
    for i = 1, #entries do
        ContextHub.AddEntryOptions(rootMenu, player, entries[i], contextData)
    end
end
