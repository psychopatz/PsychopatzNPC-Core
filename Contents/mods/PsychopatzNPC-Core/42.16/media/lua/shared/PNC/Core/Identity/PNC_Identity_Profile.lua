PNC = PNC or {}
PNC.Identity = PNC.Identity or {}

local Identity = PNC.Identity
local Archetypes = PNC.Archetypes

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
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
    if source and source.identity and source.identity.isFemale ~= nil then
        return source.identity.isFemale == true
    end
    if source and source.isFemale ~= nil then
        return source.isFemale == true
    end
    return Identity.Index(seed, "gender", 2) == 1
end

function Identity.ResolveDisplayName(source, seed, isFemale, archetypeID)
    local explicit = normalizeString(source and (source.displayName or source.name) or nil)
    if source and source.identity and normalizeString(source.identity.displayName) then
        return normalizeString(source.identity.displayName)
    end
    if explicit then
        return explicit
    end
    return "Survivor"
end

function Identity.ApplyRecordIdentity(record, source)
    local seed
    local archetype
    local resolvedIdentity
    if not record then
        return nil
    end
    seed = Identity.NormalizeSeed(
        source and (source.identitySeed or (source.identity and source.identity.seed)) or record.identitySeed,
        tostring(source and (source.displayName or source.name or source.faction) or record.id or "pnc")
    )
    archetype = Archetypes.Get(Identity.ResolveArchetypeID(source or record))
    resolvedIdentity = type(source and source.identity) == "table" and PNC.Core.DeepCopy(source.identity)
        or type(record.identity) == "table" and PNC.Core.DeepCopy(record.identity)
        or Identity.GenerateResolvedIdentity({
            id = record.id,
            displayName = source and source.displayName or source and source.name or nil,
            name = source and source.name or nil,
            isFemale = source and source.isFemale,
            archetypeID = archetype.id,
            archetypeLabel = archetype.label,
            identitySeed = seed,
        })
    resolvedIdentity.seed = seed
    resolvedIdentity.archetypeID = archetype.id
    resolvedIdentity.archetypeLabel = archetype.label
    resolvedIdentity.displayName = Identity.ResolveDisplayName({ identity = resolvedIdentity, displayName = source and source.displayName or nil, name = source and source.name or nil }, seed, resolvedIdentity.isFemale == true, archetype.id)
    record.identity = resolvedIdentity
    record.identitySeed = resolvedIdentity.seed
    record.archetypeID = resolvedIdentity.archetypeID
    record.archetypeLabel = resolvedIdentity.archetypeLabel
    record.isFemale = resolvedIdentity.isFemale == true
    record.name = resolvedIdentity.displayName
    record.visualProfile = normalizeString(source and source.visualProfile or record.visualProfile) or archetype.visualProfile
    record.outfit = normalizeString(source and source.outfit or record.outfit) or nil
    record.allowedJobs = PNC.Core.DeepCopy(archetype.allowedJobs or record.allowedJobs or {})
    return record
end

function Identity.RollAppearance(record)
    local archetype
    local genderKey
    local seed
    local lookPool
    local look
    local survivor
    local spawnOutfit
    local runtime
    local hairColor
    local cacheKey
    if not record then
        return nil
    end
    Identity.ApplyRecordIdentity(record, record)
    seed = Identity.NormalizeSeed(record.identitySeed, record.id)
    archetype = Archetypes.Get(record.archetypeID)
    genderKey = record.isFemale and "female" or "male"
    lookPool = archetype.looks and archetype.looks[genderKey] or nil
    look = choose(lookPool, seed, "look:" .. tostring(archetype.id))
    survivor = record.identity and record.identity.survivor or {}
    spawnOutfit = archetype.looks and archetype.looks.spawnOutfit or {}
    hairColor = survivor.hairColor or {}
    runtime = record.runtime or {}
    record.runtime = runtime
    cacheKey = table.concat({
        tostring(seed),
        tostring(archetype.id),
        tostring(record.isFemale == true),
        tostring(record.outfit or ""),
        tostring(survivor.skinTexture or ""),
        tostring(survivor.hairModel or ""),
        tostring(survivor.beardModel or ""),
        tostring(hairColor.r or ""),
        tostring(hairColor.g or ""),
        tostring(hairColor.b or ""),
    }, "|")
    if runtime.appearanceCacheKey == cacheKey and runtime.appearanceCache then
        return runtime.appearanceCache
    end
    runtime.appearanceCache = {
        outfit = record.outfit or (record.isFemale and spawnOutfit.female or spawnOutfit.male),
        outfitItems = type(look) == "table" and PNC.Core.DeepCopy(look) or {},
        skinTexture = survivor.skinTexture,
        hairModel = survivor.hairModel,
        beardModel = record.isFemale and nil or survivor.beardModel,
        hairColor = survivor.hairColor,
        voice = survivor.voice,
    }
    runtime.appearanceCacheKey = cacheKey
    return runtime.appearanceCache
end

function Identity.GetCharacterSummary(record)
    local archetype = Archetypes.Get(record and record.archetypeID or nil)
    local identity = record and record.identity or {}
    return {
        displayName = identity.displayName or record and record.name or "Unknown",
        archetypeID = archetype.id,
        archetypeLabel = archetype.label,
        identitySeed = identity.seed or record and record.identitySeed or 1,
        isFemale = identity.isFemale == true or record and record.isFemale == true or false,
        recruited = record and record.recruited == true or false,
        faction = record and record.faction or "companion",
        survivor = PNC.Core.DeepCopy(identity.survivor or {}),
    }
end
