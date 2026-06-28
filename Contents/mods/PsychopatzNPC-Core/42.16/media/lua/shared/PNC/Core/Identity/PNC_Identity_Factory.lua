PNC = PNC or {}
PNC.Identity = PNC.Identity or {}

local Identity = PNC.Identity
local Names = PNC.IdentityNames

local function normalizeString(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function colorToTable(color)
    if not color then
        return nil
    end
    if color.getRedFloat and color.getGreenFloat and color.getBlueFloat then
        return {
            r = tonumber(color:getRedFloat()) or 0.2,
            g = tonumber(color:getGreenFloat()) or 0.1,
            b = tonumber(color:getBlueFloat()) or 0.1,
        }
    end
    return {
        r = tonumber(color.r) or 0.2,
        g = tonumber(color.g) or 0.1,
        b = tonumber(color.b) or 0.1,
    }
end

local function tryCreateSurvivor()
    local ok
    local desc
    if not SurvivorFactory or not SurvivorFactory.CreateSurvivor then
        return nil
    end
    if SurvivorType and SurvivorType.Neutral then
        ok, desc = pcall(SurvivorFactory.CreateSurvivor, SurvivorType.Neutral, false)
        if ok and desc then
            return desc
        end
    end
    ok, desc = pcall(SurvivorFactory.CreateSurvivor)
    if ok and desc then
        return desc
    end
    return nil
end

function Identity.GenerateResolvedIdentity(source)
    local seed = Identity.NormalizeSeed(source and source.identitySeed or nil, tostring(source and source.id or "npc"))
    local desc = tryCreateSurvivor()
    local humanVisual = desc and desc.getHumanVisual and desc:getHumanVisual() or nil
    local explicitName = normalizeString(source and (source.displayName or source.name) or nil)
    local explicitFemale = source and source.isFemale
    local resolvedFemale = explicitFemale
    local forename
    local surname
    local displayName
    local hairColor
    if resolvedFemale == nil and desc and desc.isFemale then
        resolvedFemale = desc:isFemale()
    end
    if resolvedFemale == nil then
        resolvedFemale = Identity.Index(seed, "gender:fallback", 2) == 1
    else
        resolvedFemale = resolvedFemale == true
    end
    if desc and desc.setFemale then
        pcall(function()
            desc:setFemale(resolvedFemale)
        end)
    end
    forename = desc and desc.getForename and normalizeString(desc:getForename()) or nil
    surname = desc and desc.getSurname and normalizeString(desc:getSurname()) or nil
    if humanVisual and humanVisual.getHairColor then
        hairColor = colorToTable(humanVisual:getHairColor())
    end
    displayName = explicitName
    if not displayName then
        if forename or surname then
            displayName = table.concat({
                tostring(forename or ""),
                tostring(surname or ""),
            }, " ")
            displayName = string.gsub(displayName, "^%s+", "")
            displayName = string.gsub(displayName, "%s+$", "")
        end
    end
    if not displayName or displayName == "" then
        displayName = Names and Names.Generate and Names.Generate(seed, resolvedFemale, source and source.archetypeID or nil) or "Survivor"
    end
    return {
        seed = seed,
        archetypeID = normalizeString(source and source.archetypeID or nil),
        archetypeLabel = normalizeString(source and source.archetypeLabel or nil),
        displayName = displayName,
        isFemale = resolvedFemale,
        survivor = {
            forename = forename,
            surname = surname,
            hairModel = humanVisual and humanVisual.getHairModel and normalizeString(humanVisual:getHairModel()) or nil,
            beardModel = humanVisual and humanVisual.getBeardModel and normalizeString(humanVisual:getBeardModel()) or nil,
            hairColor = hairColor,
            skinTexture = humanVisual and humanVisual.getSkinTexture and normalizeString(humanVisual:getSkinTexture()) or nil,
            voice = desc and desc.getVoicePrefix and normalizeString(desc:getVoicePrefix()) or nil,
        },
    }
end

