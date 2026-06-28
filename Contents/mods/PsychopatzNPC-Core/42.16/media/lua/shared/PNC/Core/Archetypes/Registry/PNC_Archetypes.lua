PNC = PNC or {}
PNC.Archetypes = PNC.Archetypes or {}

local Archetypes = PNC.Archetypes
local Core = PNC.Core

Archetypes.Registry = Archetypes.Registry or {
    definitions = {},
    looks = {},
    skills = {},
    loadouts = {},
    modules = {},
    moduleOrder = {},
    loadedModules = {},
    companionDefaults = {},
    hostileDefaults = {},
}

local Registry = Archetypes.Registry

local function appendUnique(list, value)
    local i
    if type(list) ~= "table" or value == nil then
        return
    end
    for i = 1, #list do
        if list[i] == value then
            return
        end
    end
    list[#list + 1] = value
end

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function normalizeDefaults(list)
    local output = {}
    local i
    if type(list) ~= "table" then
        return output
    end
    for i = 1, #list do
        if normalizeString(list[i]) then
            output[#output + 1] = tostring(list[i])
        end
    end
    return output
end

function PNC.RegisterArchetype(id, data)
    local entry
    id = normalizeString(id)
    if not id or type(data) ~= "table" then
        return false
    end
    entry = Core.DeepCopy(data)
    entry.id = id
    entry.label = normalizeString(entry.label or entry.name) or id
    entry.tags = type(entry.tags) == "table" and Core.DeepCopy(entry.tags) or {}
    entry.type = normalizeString(entry.type) or "survivor"
    entry.visualProfile = normalizeString(entry.visualProfile) or "companion"
    entry.allowedJobs = type(entry.allowedJobs) == "table" and Core.DeepCopy(entry.allowedJobs) or {}
    Registry.definitions[id] = entry
    if entry.defaultForFaction == "companion" then
        appendUnique(Registry.companionDefaults, id)
    elseif entry.defaultForFaction == "hostile" then
        appendUnique(Registry.hostileDefaults, id)
    end
    return true
end

function PNC.RegisterArchetypeModule(id, spec)
    local entry
    id = normalizeString(id)
    if not id then
        return false
    end
    entry = type(spec) == "table" and Core.DeepCopy(spec) or {}
    entry.id = id
    entry.modulePath = normalizeString(entry.modulePath) or ("PNC/ArchetypeDefinitions/" .. id .. "/PNC_" .. id)
    Registry.modules[id] = entry
    appendUnique(Registry.moduleOrder, id)
    return true
end

function Archetypes.GetModuleList()
    return normalizeDefaults(Registry.moduleOrder)
end

function Archetypes.GetModuleSpec(id)
    id = normalizeString(id)
    if not id then
        return nil
    end
    return Registry.modules[id] and Core.DeepCopy(Registry.modules[id]) or nil
end

function Archetypes.LoadModule(id)
    local spec
    local ok
    local err
    id = normalizeString(id)
    if not id then
        return false, "missing_id"
    end
    if Registry.loadedModules[id] == true then
        return true, "already_loaded"
    end
    spec = Registry.modules[id] or { id = id, modulePath = "PNC/ArchetypeDefinitions/" .. id .. "/PNC_" .. id }
    Registry.modules[id] = spec
    appendUnique(Registry.moduleOrder, id)
    ok, err = pcall(require, spec.modulePath)
    if not ok then
        return false, tostring(err)
    end
    Registry.loadedModules[id] = true
    return true, spec.modulePath
end

function Archetypes.LoadModules()
    local moduleIDs = Archetypes.GetModuleList()
    local totalLoaded = 0
    local errors = {}
    local i
    local ok
    local reason
    for i = 1, #moduleIDs do
        ok, reason = Archetypes.LoadModule(moduleIDs[i])
        if ok then
            if reason ~= "already_loaded" then
                totalLoaded = totalLoaded + 1
            end
        else
            errors[#errors + 1] = {
                id = moduleIDs[i],
                reason = reason,
            }
        end
    end
    return totalLoaded, errors
end

function PNC.LoadArchetypes()
    return Archetypes.LoadModules()
end

function PNC.RegisterArchetypeLooks(id, data)
    id = normalizeString(id)
    if not id or type(data) ~= "table" then
        return false
    end
    Registry.looks[id] = Core.DeepCopy(data)
    return true
end

function PNC.RegisterArchetypeSkills(id, data)
    id = normalizeString(id)
    if not id or type(data) ~= "table" then
        return false
    end
    Registry.skills[id] = Core.DeepCopy(data)
    return true
end

function PNC.RegisterArchetypeLoadout(id, data)
    id = normalizeString(id)
    if not id or type(data) ~= "table" then
        return false
    end
    Registry.loadouts[id] = Core.DeepCopy(data)
    return true
end

function Archetypes.Get(id)
    local key = normalizeString(id) or "General"
    local definition = Registry.definitions[key] or Registry.definitions.General or {
        id = key,
        label = key,
        visualProfile = "companion",
        tags = {},
        allowedJobs = {},
    }
    return {
        id = definition.id,
        label = definition.label,
        type = definition.type,
        tags = Core.DeepCopy(definition.tags or {}),
        visualProfile = definition.visualProfile,
        allowedJobs = Core.DeepCopy(definition.allowedJobs or {}),
        defaultForFaction = definition.defaultForFaction,
        looks = Core.DeepCopy(Registry.looks[key] or Registry.looks.General or {}),
        skillBias = Core.DeepCopy(Registry.skills[key] or Registry.skills.General or {}),
        loadout = Core.DeepCopy(Registry.loadouts[key] or Registry.loadouts.General or {}),
    }
end

function Archetypes.GetCompanionDefaults()
    local defaults = normalizeDefaults(Registry.companionDefaults)
    if #defaults <= 0 then
        defaults[1] = "General"
    end
    return defaults
end

function Archetypes.GetHostileDefaults()
    local defaults = normalizeDefaults(Registry.hostileDefaults)
    if #defaults <= 0 then
        defaults[1] = "Scavenger"
    end
    return defaults
end

function Archetypes.List()
    local output = {}
    local id
    for id, _ in pairs(Registry.definitions) do
        output[id] = Archetypes.Get(id)
    end
    return output
end
