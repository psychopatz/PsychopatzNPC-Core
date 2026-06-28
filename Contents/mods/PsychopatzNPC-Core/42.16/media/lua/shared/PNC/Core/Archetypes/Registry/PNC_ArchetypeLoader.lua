--[[
    PNC Archetype Loader
    Owns importer-driven archetype module bootstrapping. The importer registers
    module IDs; the loader resolves and requires them once.
]]

PNC = PNC or {}
PNC.Archetypes = PNC.Archetypes or {}

local Archetypes = PNC.Archetypes
local Core = PNC.Core

local function joinModuleIDs(moduleIDs)
    local output = {}
    local i
    if type(moduleIDs) ~= "table" then
        return ""
    end
    for i = 1, #moduleIDs do
        output[#output + 1] = tostring(moduleIDs[i])
    end
    return table.concat(output, ", ")
end

local function loadDefaults()
    local totalLoaded
    local errors
    local moduleIDs
    local appliedBundles
    local definitionCount
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
    if Archetypes.ApplyPendingBundles then
        appliedBundles = Archetypes.ApplyPendingBundles()
    end
    moduleIDs = Archetypes.GetModuleList and Archetypes.GetModuleList() or {}
    Core.LogInfo(
        "PNC archetype loader starting. Modules="
            .. tostring(#moduleIDs)
            .. " ["
            .. joinModuleIDs(moduleIDs)
            .. "] pendingBundles="
            .. tostring(appliedBundles or 0)
    )
    totalLoaded, errors = Archetypes.LoadModules()
    if Archetypes.ApplyPendingBundles then
        Archetypes.ApplyPendingBundles()
    end
    if type(errors) == "table" then
        for i = 1, #errors do
            Core.LogWarn("PNC archetype loader failed for " .. tostring(errors[i].id) .. ": " .. tostring(errors[i].reason))
        end
    end
    definitionCount = Archetypes.List and Core.TableSize(Archetypes.List()) or 0
    Core.LogInfo(
        "PNC archetype loader ready. Loaded modules="
            .. tostring(totalLoaded or 0)
            .. " registeredDefinitions="
            .. tostring(definitionCount)
    )
    if definitionCount <= 1 then
        Core.LogWarn("PNC archetype registry is nearly empty after bootstrap. Check common archetype definition preload/order.")
    end
end

loadDefaults()
