--[[
    PNC Archetype Importer
    Registers archetype module IDs from common content so runtime loaders do
    not need one require per archetype definition file.
]]

PNC = PNC or {}

local importerModules = {
    "General",
    "Farmer",
    "Mechanic",
    "Doctor",
    "Foreman",
    "Scavenger",
}

PNC.ArchetypeImporter = PNC.ArchetypeImporter or {}
PNC.ArchetypeImporter.modules = importerModules

local i

for i = 1, #importerModules do
    if PNC.RegisterArchetypeModule then
        PNC.RegisterArchetypeModule(importerModules[i])
    end
end

PNC.ArchetypeImporterLoaded = true
