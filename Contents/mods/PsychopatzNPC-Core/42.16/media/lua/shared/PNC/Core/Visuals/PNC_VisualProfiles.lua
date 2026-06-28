PNC = PNC or {}
PNC.VisualProfiles = PNC.VisualProfiles or {}

local Profiles = PNC.VisualProfiles
local Identity = PNC.Identity

Profiles.Named = Profiles.Named or {
    companion = {
        male = {
            outfit = "PNCCompanionMale",
            skinTextures = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            hairModels = { "Baldspot", "Messy", "Short", "Recede" },
            beardModels = { "FullBeard", "Goatee", "Moustache", "ShortBoxedBeard" },
        },
        female = {
            outfit = "PNCCompanionFemale",
            skinTextures = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
            hairModels = { "Ponytail", "Long2", "Bob", "StraightLong" },
        },
    },
    hostile = {
        male = {
            outfit = "PNCHostileMale",
            skinTextures = { "MaleBody02", "MaleBody03", "MaleBody04" },
            hairModels = { "Messy", "Short", "Baldspot" },
            beardModels = { "FullBeard", "Goatee", "Stubble" },
        },
        female = {
            outfit = "PNCHostileFemale",
            skinTextures = { "FemaleBody02", "FemaleBody03", "FemaleBody04" },
            hairModels = { "Long2", "Ponytail", "Messy" },
        },
    },
}

local function chooseFromList(record, key, list)
    if type(list) ~= "table" or #list <= 0 then
        return nil
    end
    return list[Identity.Index(record and record.identitySeed or 1, key, #list)]
end

function Profiles.Resolve(record)
    local bucket
    local genderKey
    if not record then
        return nil
    end
    bucket = Profiles.Named[tostring(record.visualProfile or record.faction or "companion")] or Profiles.Named.companion
    genderKey = record.isFemale and "female" or "male"
    return bucket[genderKey] or bucket.male or bucket.female
end

function Profiles.ResolveSpawnOutfit(record)
    local profile = Profiles.Resolve(record)
    if record and record.outfit and record.outfit ~= "" then
        return tostring(record.outfit)
    end
    return profile and profile.outfit or (record and record.isFemale and "PNCCompanionFemale" or "PNCCompanionMale")
end

function Profiles.RollAppearance(record)
    local profile = Profiles.Resolve(record) or {}
    return {
        outfit = Profiles.ResolveSpawnOutfit(record),
        skinTexture = chooseFromList(record, "skin", profile.skinTextures),
        hairModel = chooseFromList(record, "hair", profile.hairModels),
        beardModel = record and record.isFemale and nil or chooseFromList(record, "beard", profile.beardModels),
    }
end
