PNC = PNC or {}
PNC.Archetypes = PNC.Archetypes or {}

local Archetypes = PNC.Archetypes
local Core = PNC.Core

local defaultArchetypeModules = {
    "General",
    "Farmer",
    "Mechanic",
    "Doctor",
    "Foreman",
    "Scavenger",
}

local function registerDefaults()
    local i
    for i = 1, #defaultArchetypeModules do
        if PNC.RegisterArchetypeModule then
            PNC.RegisterArchetypeModule(defaultArchetypeModules[i])
        end
    end
end

local function loadDefaults()
    local totalLoaded
    local errors
    local i
    registerDefaults()
    if not Archetypes.LoadModules then
        return
    end
    totalLoaded, errors = Archetypes.LoadModules()
    if type(errors) == "table" then
        for i = 1, #errors do
            Core.LogWarn("PNC archetype loader failed for " .. tostring(errors[i].id) .. ": " .. tostring(errors[i].reason))
        end
    end
    Core.LogInfo("PNC archetype loader ready. Loaded modules: " .. tostring(totalLoaded or 0))
end

loadDefaults()
