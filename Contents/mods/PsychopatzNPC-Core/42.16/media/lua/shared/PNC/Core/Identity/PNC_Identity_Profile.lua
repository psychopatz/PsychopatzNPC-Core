PNC = PNC or {}
PNC.Identity = PNC.Identity or {}

local Identity = PNC.Identity
local Archetypes = PNC.Archetypes
local Names = PNC.IdentityNames
local Core = PNC.Core

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function copyList(list)
    local result = {}
    local i
    if type(list) ~= "table" then
        return result
    end
    for i = 1, #list do
        result[i] = list[i]
    end
    return result
end

local function choose(list, seed, salt)
    if type(list) ~= "table" or #list <= 0 then
        return nil
    end
    return list[Identity.Index(seed, salt, #list)]
end

function Identity.ResolveArchetypeID(source)
    local seed
    local faction
    local options
    local explicit = normalizeString(source and source.archetypeID or nil)
    if explicit and Archetypes.Get(explicit) then
        return Archetypes.Get(explicit).id
    end
    seed = Identity.NormalizeSeed(source and source.identitySeed or nil, tostring(source and source.faction or "companion"))
    faction = tostring(source and source.faction or "companion")
    options = faction == "hostile" and Archetypes.GetHostileDefaults() or Archetypes.GetCompanionDefaults()
    return tostring(choose(options, seed, "archetype:" .. faction) or "General")
end

function Identity.ResolveIsFemale(source, seed)
    if source and source.isFemale ~= nil then
        return source.isFemale == true
    end
    return Identity.Index(seed, "gender", 2) == 1
end

function Identity.ResolveDisplayName(source, seed, isFemale, archetypeID)
    local explicit = normalizeString(source and (source.displayName or source.name) or nil)
    if explicit then
        return explicit
    end
    return Names.Generate(seed, isFemale, archetypeID)
end

function Identity.ApplyRecordIdentity(record, source)
    local seed
    local archetype
    if not record then
        return nil
    end
    seed = Identity.NormalizeSeed(
        source and source.identitySeed or record.identitySeed,
        tostring(source and (source.displayName or source.name or source.faction) or record.id or "pnc")
    )
    archetype = Archetypes.Get(Identity.ResolveArchetypeID(source or record))
    record.identitySeed = seed
    record.archetypeID = archetype.id
    record.archetypeLabel = archetype.label
    record.isFemale = Identity.ResolveIsFemale(source or record, seed)
    record.name = Identity.ResolveDisplayName(source or record, seed, record.isFemale, archetype.id)
    record.visualProfile = normalizeString(source and source.visualProfile or record.visualProfile) or archetype.visualProfile
    record.outfit = normalizeString(source and source.outfit or record.outfit)
        or (record.isFemale and archetype.spawnOutfit.female or archetype.spawnOutfit.male)
    return record
end

function Identity.RollAppearance(record)
    local archetype
    local genderKey
    local seed
    local lookPool
    local look
    if not record then
        return nil
    end
    Identity.ApplyRecordIdentity(record, record)
    seed = Identity.NormalizeSeed(record.identitySeed, record.id)
    archetype = Archetypes.Get(record.archetypeID)
    genderKey = record.isFemale and "female" or "male"
    lookPool = archetype.looks and archetype.looks[genderKey] or nil
    look = choose(lookPool, seed, "look:" .. tostring(archetype.id))
    return {
        outfit = record.outfit or (record.isFemale and archetype.spawnOutfit.female or archetype.spawnOutfit.male),
        outfitItems = copyList(look),
        skinTexture = choose(archetype.skin and archetype.skin[genderKey] or nil, seed, "skin:" .. tostring(archetype.id)),
        hairModel = choose(archetype.hair and archetype.hair[genderKey] or nil, seed, "hair:" .. tostring(archetype.id)),
        beardModel = record.isFemale and nil or choose(archetype.beard, seed, "beard:" .. tostring(archetype.id)),
    }
end

function Identity.GetCharacterSummary(record)
    local archetype = Archetypes.Get(record and record.archetypeID or nil)
    return {
        displayName = record and record.name or "Unknown",
        archetypeID = archetype.id,
        archetypeLabel = archetype.label,
        identitySeed = record and record.identitySeed or 1,
        isFemale = record and record.isFemale == true or false,
        recruited = record and record.recruited == true or false,
        faction = record and record.faction or "companion",
    }
end

