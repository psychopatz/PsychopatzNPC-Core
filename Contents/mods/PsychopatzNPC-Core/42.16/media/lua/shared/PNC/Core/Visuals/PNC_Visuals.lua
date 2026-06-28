PNC = PNC or {}
PNC.Visuals = PNC.Visuals or {}

local Visuals = PNC.Visuals
local Profiles = PNC.VisualProfiles
local Equipment = PNC.Equipment

local function normalizeBodyLocation(value)
    local lowered
    local stripped
    local canonical
    local ordered = {
        "UnderwearBottom", "UnderwearTop", "UnderwearExtra1", "UnderwearExtra2", "Underwear", "Codpiece", "Torso1Legs1", "Legs1",
        "Ears", "EarTop", "Nose", "Hat", "FullHat", "SCBA", "Mask", "MaskEyes", "Eyes", "RightEye", "LeftEye",
        "Neck", "Necklace", "Necklace_Long", "Gorget", "Scarf", "Pants", "Pants_Skinny", "PantsExtra", "ShortPants", "ShortsShort",
        "LongSkirt", "Skirt", "Dress", "LongDress", "TankTop", "Tshirt", "ShortSleeveShirt", "Shirt", "Jersey", "VestTexture",
        "Sweater", "SweaterHat", "TorsoExtraVest", "Cuirass", "TorsoExtra", "Jacket", "JacketHat", "Jacket_Down", "JacketHat_Bulky",
        "Jacket_Bulky", "JacketSuit", "FullTop", "RightWrist", "Right_MiddleFinger", "Right_RingFinger", "LeftWrist",
        "Left_MiddleFinger", "Left_RingFinger", "Hands", "HandsRight", "HandsLeft", "BathRobe", "FullSuit", "FullSuitHead",
        "Boilersuit", "Tail", "TorsoExtraVestBullet", "ShoulderpadRight", "ShoulderpadLeft", "Elbow_Right", "Elbow_Left",
        "ForeArm_Right", "ForeArm_Left", "Thigh_Right", "Thigh_Left", "Knee_Right", "Knee_Left", "Calf_Right", "Calf_Left",
        "FannyPackFront", "FannyPackBack", "Webbing", "Back", "AmmoStrap", "AnkleHolster", "BeltExtra", "ShoulderHolster",
        "Socks", "Shoes"
    }
    local i
    value = value and tostring(value) or nil
    if not value then
        return nil
    end
    lowered = string.lower(value)
    stripped = string.match(lowered, "([^:%.]+)$") or lowered
    for i = 1, #ordered do
        canonical = ordered[i]
        if string.lower(canonical) == stripped then
            return canonical
        end
    end
    return value
end

local function makeImmutableColor(color)
    if not color or not ImmutableColor then
        return nil
    end
    return ImmutableColor.new(
        tonumber(color.r) or 0.2,
        tonumber(color.g) or 0.1,
        tonumber(color.b) or 0.1
    )
end

local function clearBodySoiledState(humanVisual)
    local maxIndex
    local i
    local part
    if not humanVisual then
        return
    end
    if humanVisual.removeDirt then
        humanVisual:removeDirt()
    end
    if humanVisual.removeBlood then
        humanVisual:removeBlood()
    end
    if not BloodBodyPartType or not BloodBodyPartType.MAX or not BloodBodyPartType.FromIndex then
        return
    end
    maxIndex = BloodBodyPartType.MAX:index()
    for i = 0, maxIndex - 1 do
        part = BloodBodyPartType.FromIndex(i)
        humanVisual:setBlood(part, 0)
        humanVisual:setDirt(part, 0)
    end
end

local function clearAttachedItems(zombie)
    local attachedItems
    local i
    local entry
    local item
    if not zombie or not zombie.getAttachedItems then
        return
    end
    attachedItems = zombie:getAttachedItems()
    if not attachedItems then
        return
    end
    for i = attachedItems:size() - 1, 0, -1 do
        entry = attachedItems:get(i)
        item = entry and entry.getItem and entry:getItem() or nil
        if item and zombie.removeAttachedItem then
            zombie:removeAttachedItem(item)
        end
    end
end

local function refreshModel(zombie)
    if not zombie then
        return
    end
    if zombie.resetModelNextFrame then
        zombie:resetModelNextFrame()
    end
    if zombie.resetModel then
        zombie:resetModel()
    end
end

local function safeSetWornItem(zombie, item)
    local bodyLocation
    if not zombie or not item or not zombie.setWornItem then
        return false
    end
    bodyLocation = item.getBodyLocation and item:getBodyLocation() or nil
    bodyLocation = normalizeBodyLocation(bodyLocation)
    if not bodyLocation or bodyLocation == "" then
        return false
    end
    return pcall(function()
        zombie:setWornItem(bodyLocation, item)
    end)
end

local function applyBaseOutfitItems(zombie, appearance)
    local items
    local i
    local item
    local reason
    if not zombie or not appearance then
        return
    end
    items = appearance.outfitItems
    if type(items) ~= "table" or not Equipment or not Equipment.CreateItem then
        return
    end
    for i = 1, #items do
        item, reason = Equipment.CreateItem(items[i])
        if item then
            safeSetWornItem(zombie, item)
        elseif reason and reason ~= "invalid_full_type" then
            PNC.Core.LogWarn("PNC visuals could not create outfit item " .. tostring(items[i]) .. ": " .. tostring(reason))
        end
    end
end

function Visuals.ApplyHumanVisuals(zombie, record)
    local appearance
    local humanVisual
    local itemVisuals
    local wornItems

    if not zombie or not record then
        return
    end

    appearance = Profiles.RollAppearance(record)
    if zombie.setFemaleEtc then
        zombie:setFemaleEtc(record.isFemale == true)
    end

    humanVisual = zombie.getHumanVisual and zombie:getHumanVisual() or nil
    itemVisuals = zombie.getItemVisuals and zombie:getItemVisuals() or nil
    wornItems = zombie.getWornItems and zombie:getWornItems() or nil

    if itemVisuals and itemVisuals.clear then
        itemVisuals:clear()
    end
    if wornItems and wornItems.clear then
        wornItems:clear()
    end

    clearAttachedItems(zombie)
    clearBodySoiledState(humanVisual)

    if zombie.dressInNamedOutfit then
        zombie:dressInNamedOutfit(appearance.outfit)
    end
    applyBaseOutfitItems(zombie, appearance)

    if humanVisual then
        if appearance.skinTexture and humanVisual.setSkinTextureName then
            humanVisual:setSkinTextureName(appearance.skinTexture)
        end
        if appearance.hairModel and humanVisual.setHairModel then
            humanVisual:setHairModel(appearance.hairModel)
        end
        if appearance.beardModel and humanVisual.setBeardModel then
            humanVisual:setBeardModel(appearance.beardModel)
        end
        if appearance.hairColor then
            local immutableColor = makeImmutableColor(appearance.hairColor)
            if immutableColor and humanVisual.setHairColor then
                humanVisual:setHairColor(immutableColor)
            end
            if immutableColor and humanVisual.setBeardColor then
                humanVisual:setBeardColor(immutableColor)
            end
        end
    end

    refreshModel(zombie)
end
