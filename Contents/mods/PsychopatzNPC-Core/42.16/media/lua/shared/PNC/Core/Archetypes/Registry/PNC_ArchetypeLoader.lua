--[[
    PNC Archetype Loader
    Owns importer-driven archetype module bootstrapping. The importer registers
    module IDs; the loader resolves and requires them once.
]]

PNC = PNC or {}
PNC.Archetypes = PNC.Archetypes or {}

local Archetypes = PNC.Archetypes
local Core = PNC.Core

local function loadDefaults()
    local totalLoaded
    local errors
    local i
    if not PNC.ArchetypeImporterLoaded then
        if PNC.ArchetypeImporter and type(PNC.ArchetypeImporter.modules) == "table" and PNC.RegisterArchetypeModule then
            for i = 1, #PNC.ArchetypeImporter.modules do
                PNC.RegisterArchetypeModule(PNC.ArchetypeImporter.modules[i])
            end
            PNC.ArchetypeImporterLoaded = true
        else
            require "PNC/ArchetypeDefinitions/PNC_ArchetypeImporter"
        end
    end
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
